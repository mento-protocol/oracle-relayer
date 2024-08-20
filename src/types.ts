export interface PubsubData {
  subscription: string;
  message: {
    messageId: string;
    publishTime: string;
    data: string;
    attributes?: Record<string, string>;
  };
}

export interface RelayRequested {
  rate_feed_name: string;
  relayer_address: string;
}
