namespace Share_Care.Services
{
    public interface IRewardsService
    {
        Task<bool> AwardCreditsAsync(string userId, int credits);
        Task<bool> AwardGiverBonusAsync(string giverId, decimal bonusAmount);
        Task<bool> ConvertWalletToCreditsAsync(string userId, decimal amount);
    }
}
