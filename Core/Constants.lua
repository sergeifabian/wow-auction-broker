local AuctionBroker = _G.AuctionBroker or {}
_G.AuctionBroker = AuctionBroker

AuctionBroker.Constants = {
    QUERY_DELAY = 0.5,
    QUERY_TIMEOUT = 10,
    EMPTY_GRACE = 2.5,
    MAX_RETRIES = 2,
    MAX_MORE_PAGES = 10,
    MAX_LINES = 12,
}