using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Share_Care.models;

namespace Share_Care.Tests.Helpers
{
    public static class TestData
    {
        public static Wallet Wallet(decimal balance = 100)
            => new Wallet { UserId = "user1", Balance = balance };

        public static Transaction Transaction(decimal amount = 100)
            => new Transaction
            {
                Id = "tx1",
                UserId = "user1",
                Amount = amount,
                Status = "Pending"
            };

        public static Escrow Escrow()
            => new Escrow
            {
                Id = "esc1",
                BorrowerId = "borrower",
                LenderId = "lender",
                OfferId = "offer1",
                Amount = 50,
                Status = "Locked"
            };
    }
}
