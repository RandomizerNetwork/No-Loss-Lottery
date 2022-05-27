module.exports = {
    TEAM_TREASURY_GNOSIS_SAFE: "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", // DAILY DRAW TREASURY MULTISG WALLET
    RNDD_TREASURY_GNOSIS_SAFE: "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", // DAILY DRAW TREASURY MULTISG WALLET
    LOCKED_BURNABLE_TOKENS: "500000000",       // 500M RANDOM (50%) - locked and burned gradually in 10 years
    LOCKED_DAO_TOKENS: "250000000",            // 250M RANDOM (25%) - locked and released gradually in 5 years
    TOTAL_DAILY_DRAW_TOKENS: "100000000", // 100M RANDOM (10%) - locked and released gradually in 10 years
    TOTAL_CONTRIBUTOR_TOKENS: "50000000",      //  50M RANDOM  (5%) - locked and released gradually in 5 years
    TOTAL_STAKING_TOKENS: "50000000",          //  50M RANDOM  (5%) - locked and released gradually in 10 years
    TOTAL_YIELD_FARMING_TOKENS: "50000000",    //  50M RANDOM  (5%) - locked and released gradually in 10 years
    VOTING_DELAY: "1", // 1 block
    VOTING_PERIOD: "45818", // 1 week in blocks
    VOTING_MIN_POWER: "0", // anyone can propose
    VOTING_PERCENTAGE: "4", // 4 percent
    MIN_TIMELOCK_DELAY: "3600", // 1 hour in dev // Queing for 172800 seconds in production for 1 week
    EXECUTORS: [],
    PROPOSERS: [],
    UNLOCK_BEGIN: "2022-06-10",
    UNLOCK_CLIFF: "2022-07-10",
    UNLOCK_END: "2025-12-01"
}