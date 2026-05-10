using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public interface IEscrowService
    {
        Task<Escrow?> CreateEscrowAsync(string borrowerId, string lenderId, string offerId, decimal amount, DateTime? deadlineAt);
        Task<Escrow> GetEscrowByOfferIdAsync(string offerId);
        Task<Escrow> GetEscrowByUserIdAsync(string userId);
        Task<bool> ApproveEscrowAsync(string offerId);
        Task<bool> CancelEscrowAsync(string offerId);
        Task<bool> RecordTakerReturnAsync(string offerId, List<string> imageIds);
        Task<bool> RecordGiverInspectionAsync(string offerId, string condition, List<string> imageIds);
        Task<bool> FinalizeEscrowAsync(string offerId, string condition, string platformUserId, decimal platformFeeRate, decimal giverBonusRate);
        Task<bool> ClaimEscrowAsync(string offerId, string platformUserId, decimal platformFeeRate, decimal giverBonusRate);
        Task<List<Escrow>> GetExpiredInspectionsAsync();
        Task<bool> ClaimExpiredEscrowAsync(string offerId, string platformUserId, decimal platformFeeRate);
        Task<bool> SetInspectionDeadlineAsync(string offerId, int daysUntilDeadline = 14);
    }
}