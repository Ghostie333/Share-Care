using MongoDB.Driver;
using Share_Care.models;

namespace Share_Care.Services
{
    public interface IEscrowService
    {
        Task<Escrow> CreateEscrow();
        Task<Escrow> GetEscrowById();
        Task<Escrow> GetEscrowByUserId();
        bool LockDepsoit();
        Task<decimal> ReleaseEscrow();
        Task<decimal> ClaimEscrow();
        Task<bool> CancelEscrow();
        bool IsEscrowActive();

    }
}