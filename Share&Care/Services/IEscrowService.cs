using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public interface IEscrowService
    {
        Task<Escrow> CreateEscrowAsync(string borrowerId, string lenderId, string offerId, decimal amount);
        Task<Escrow> GetEscrowByOfferIdAsync(string offerId);
        Task<Escrow> GetEscrowByUserIdAsync(string userId);
        Task<bool> ReleaseEscrowAsync(string offerId);
        Task<bool> ClaimEscrowAsync(string offerId);
        //Task<bool> CancelEscrowAsync();
        //bool IsEscrowActive();

    }
}