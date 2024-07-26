import { cloudEvent, CloudEvent } from "@google-cloud/functions-framework";

interface PubsubData {
  subscription: string;
  message: {
    messageId: string;
    publishTime: string;
    data: string;
    attributes?: {[key: string]: string};
  };
}

interface RelayRequested {
  relayer_address: string;
};

cloudEvent('relay', (event: CloudEvent<PubsubData>) => {
  const eventData = event.data?.message?.data

  if (!eventData) {
    return { status: 'error', message: 'No event data found' };
  }

  if (typeof eventData !== 'string') {
    console.error('Invalid event data format, must be a string:', eventData);
    return { status: 'error', message: 'Invalid event data format' };
  }

  let parsedEventData, relayerAddress
  try {
    const decodedEventData = Buffer.from(eventData, 'base64').toString('utf-8')
    parsedEventData = JSON.parse(decodedEventData) as RelayRequested;
    relayerAddress = parsedEventData.relayer_address;
  } catch (error) {
    console.error('Error parsing event data:', eventData, '\n', error);
    return { status: 'error', message: 'Error parsing event data' };
  }

  if (!relayerAddress) {
    // Return an error response
    return { status: 'error', message: `Relayer address not found in event data: ${parsedEventData}` };
  }

  // Add your function logic here
  console.log(`Received 'RelayRequested' event with relayer address: ${relayerAddress}`);

  // Return a success response
  return { status: 'success' };
})