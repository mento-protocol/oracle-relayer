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
