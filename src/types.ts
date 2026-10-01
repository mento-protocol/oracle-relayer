export interface PubsubData {
  message: {
    attributes?: Record<string, string>;
    data: string;
    messageId: string;
    publishTime: string;
  };
  subscription: string;
}

export interface RelayRequested {
  rate_feed_name: string;
  relayer_address: string;
}

// Payload of the daily refill scheduler job: the rate feed keys of the chain's
// relayers, as they appear in infra/relayer_addresses.json (e.g. "eur_usd").
export interface RefillRequested {
  rate_feeds: string[];
}
