namespace Share_Care.Services
{
    public interface IRewardsService
    {
        Task<bool> AwardGiverBonusAsync(string giverId, decimal bonusAmount);
        Task<bool> ConvertWalletToCreditsAsync(string userId, decimal amount);
    }
}
