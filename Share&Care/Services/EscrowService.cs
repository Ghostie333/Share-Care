using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Driver;
using Share_Care.models;
using System.Linq;

namespace Share_Care.Services
{
    public class EscrowService(ILogger<EscrowService> logger, IMongoDatabase db,
                                IWalletService walletSerivce) : IEscrowService
    {
        private readonly ILogger<EscrowService> _logger = logger;
        private readonly IWalletService _walletService = walletSerivce;
        private readonly IMongoCollection<Escrow> _collection = db.GetCollection<Escrow>("escrows");

        public async Task<Escrow?> CreateEscrowAsync(string borrowerId, string lenderId,
            string offerId, decimal amount, DateTime? deadlineAt)
        {
            var locked = await _walletService.LockFundsAsync(borrowerId, amount);

            if (!locked)
                return null;

            var escrow = new Escrow
            {
                BorrowerId = borrowerId,
                LenderId = lenderId,
                OfferId = offerId,
                Amount = amount,
                Status = "PendingApproval",
                CreatedAt = DateTime.UtcNow,
                DeadlineAt = deadlineAt
            };

            await _collection.InsertOneAsync(escrow);

            return escrow;
        }

        public async Task<Escrow> GetEscrowByOfferIdAsync(string offerId)
        {
            try
            {
                var escrow = await _collection.Find(e => e.OfferId == offerId).FirstOrDefaultAsync();
                return escrow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać depozytu");
                return null;
            }
        }

        public async Task<Escrow> GetEscrowByUserIdAsync(string userId)
        {
            try
            {
                var escrow = await _collection.Find(e => e.BorrowerId == userId || e.LenderId == userId)
                    .FirstOrDefaultAsync();
                return escrow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Nie udało się pobrać depozytu");
                return null;
            }
        }

        public async Task<bool> ApproveEscrowAsync(string offerId)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.Status != "PendingApproval")
                return false;

            await _collection.UpdateOneAsync(
                e => e.Id == escrow.Id,
                Builders<Escrow>.Update.Set(e => e.Status, "Locked")
            );

            return true;
        }

        public async Task<bool> CancelEscrowAsync(string offerId)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || (escrow.Status != "PendingApproval" && escrow.Status != "Locked"))
                return false;

            await _walletService.UnlockFundsAsync(escrow.BorrowerId, escrow.Amount);

            await _collection.UpdateOneAsync(
                e => e.Id == escrow.Id,
                Builders<Escrow>.Update.Set(e => e.Status, "Canceled")
            );

            return true;
        }

        public async Task<bool> RecordTakerReturnAsync(string offerId, List<string> imageIds)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.Status != "Locked")
                return false;

            var update = Builders<Escrow>.Update
                .Set(e => e.ReturnStatus, "TakerReturned")
                .Set(e => e.TakerReturnedAt, DateTime.UtcNow)
                .Set(e => e.TakerReturnImageIds, imageIds);

            await _collection.UpdateOneAsync(e => e.Id == escrow.Id, update);

            return true;
        }

        public async Task<bool> FinalizeEscrowAsync(
            string offerId,
            string condition)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.Status != "Locked")
                return false;

            var (giverPercent, _) = ResolveConditionSplit(condition);

            var total = escrow.Amount;

            var giverAmount = RoundMoney(total * giverPercent);
            var takerAmount = total - giverAmount;

            var success = await ApplyTransfersAsync(
                escrow.BorrowerId,
                escrow.LenderId,
                giverAmount,
                takerAmount);

            if (!success)
                return false;

            var update = Builders<Escrow>.Update
                .Set(e => e.Status, "Released")
                .Set(e => e.ReturnStatus, "GiverReviewed")
                .Set(e => e.Condition, condition)
                .Set(e => e.GiverReviewedAt, DateTime.UtcNow)
                .Set(e => e.GiverAmount, giverAmount)
                .Set(e => e.TakerAmount, takerAmount);

            await _collection.UpdateOneAsync(e => e.Id == escrow.Id, update);

            return true;
        }

        public async Task<bool> ClaimEscrowAsync(
            string offerId)
        {
            return await FinalizeEscrowAsync(
                offerId,
                "NotReturned");
        }

        private async Task<bool> ApplyTransfersAsync(
            string borrowerId,
            string lenderId,
            decimal giverAmount,
            decimal takerAmount)
        {
            if (giverAmount > 0)
            {
                var ok = await _walletService.TransferLockedFundsAsync(
                    borrowerId,
                    lenderId,
                    giverAmount);
                if (!ok) return false;
            }

            if (takerAmount > 0)
            {
                var wallet = await _walletService.UnlockFundsAsync(
                    borrowerId,
                    takerAmount);
                if (wallet == null) return false;
            }

            return true;
        }

        private static decimal RoundMoney(decimal value)
        {
            return Math.Round(value, 2, MidpointRounding.AwayFromZero);
        }

        private static (decimal giverPercent, decimal takerPercent) ResolveConditionSplit(string condition)
        {
            var normalized = (condition ?? string.Empty).Trim().ToLowerInvariant();
            return normalized switch
            {
                "ideal" => (0m, 1m),
                "lightlyused" => (0.25m, 0.75m),
                "heavilyused" => (0.75m, 0.25m),
                "destroyed" => (1m, 0m),
                "notreturned" => (1m, 0m),
                "expiredinspection" => (0m, 1m), // 100% Takerowi, jeśli Giver nie sprawdził w terminie
                _ => (0m, 1m)
            };
        }

        public async Task<bool> RecordGiverInspectionAsync(string offerId, string condition, List<string> imageIds)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.ReturnStatus != "TakerReturned")
                return false;

            var update = Builders<Escrow>.Update
                .Set(e => e.Condition, condition)
                .Set(e => e.GiverInspectionImageIds, imageIds)
                .Set(e => e.GiverReviewedAt, DateTime.UtcNow)
                .Set(e => e.ReturnStatus, "GiverReviewed");

            await _collection.UpdateOneAsync(e => e.Id == escrow.Id, update);

            return true;
        }

        public async Task<List<Escrow>> GetExpiredInspectionsAsync()
        {
            var expired = await _collection.Find(e =>
                e.Status == "Locked" &&
                e.ReturnStatus == "TakerReturned" &&
                e.InspectionDeadlineAt != null &&
                e.InspectionDeadlineAt < DateTime.UtcNow
            ).ToListAsync();

            return expired;
        }

        public async Task<bool> ClaimExpiredEscrowAsync(
            string offerId,
            string platformUserId,
            decimal platformFeeRate)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.Status != "Locked" || escrow.ReturnStatus != "TakerReturned")
                return false;

            // Jeśli Giver nie sprawdzi w terminie - 95% do Takera, 5% platformy
            return await FinalizeEscrowAsync(offerId, "ExpiredInspection");
        }

        public async Task<bool> SetInspectionDeadlineAsync(string offerId, int daysUntilDeadline = 14)
        {
            var escrow = await GetEscrowByOfferIdAsync(offerId);

            if (escrow == null || escrow.ReturnStatus != "TakerReturned")
                return false;

            var deadline = DateTime.UtcNow.AddDays(daysUntilDeadline);

            await _collection.UpdateOneAsync(
                e => e.Id == escrow.Id,
                Builders<Escrow>.Update.Set(e => e.InspectionDeadlineAt, deadline)
            );

            return true;
        }
    }
}