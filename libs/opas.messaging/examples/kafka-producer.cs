// TODO: Add NuGet packages:
// - Confluent.Kafka
// - Google.Protobuf
// - System.Text.Json

using Confluent.Kafka;
using Google.Protobuf;
using System.Text.Json;

namespace Opas.Messaging.Examples
{
    public class KafkaProducerExample
    {
        private readonly IProducer<string, byte[]> _producer;
        
        public KafkaProducerExample()
        {
            // TODO: Configure producer
            var config = new ProducerConfig
            {
                BootstrapServers = "localhost:9092",
                // TODO: Add security config for production
            };
            
            _producer = new ProducerBuilder<string, byte[]>(config).Build();
        }
        
        public async Task PublishEventAsync<T>(string topic, T eventData, Dictionary<string, string> headers)
        {
            // TODO: Implement envelope wrapping
            // TODO: Add required headers (x-request-id, x-tenant-id, x-event-id, etc.)
            // TODO: Serialize event data to protobuf
            
            var message = new Message<string, byte[]>
            {
                Key = headers["x-event-id"],
                Value = new byte[0], // TODO: Serialized protobuf
                Headers = headers.Select(h => new Header(h.Key, System.Text.Encoding.UTF8.GetBytes(h.Value))).ToList()
            };
            
            await _producer.ProduceAsync(topic, message);
        }
        
        public void Dispose()
        {
            _producer?.Dispose();
        }
    }
}
