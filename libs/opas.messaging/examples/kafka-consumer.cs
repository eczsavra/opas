// TODO: Add NuGet packages:
// - Confluent.Kafka
// - Google.Protobuf
// - System.Text.Json

using Confluent.Kafka;
using Google.Protobuf;
using System.Text.Json;

namespace Opas.Messaging.Examples
{
    public class KafkaConsumerExample
    {
        private readonly IConsumer<string, byte[]> _consumer;

        public KafkaConsumerExample()
        {
            // TODO: Configure consumer
            var config = new ConsumerConfig
            {
                BootstrapServers = "localhost:9092",
                GroupId = "opas-consumer-group",
                AutoOffsetReset = AutoOffsetReset.Earliest,
                EnableAutoCommit = false,
                // TODO: Add security config for production
            };

            _consumer = new ConsumerBuilder<string, byte[]>(config).Build();
        }

        public void StartConsuming(string topic)
        {
            _consumer.Subscribe(topic);

            try
            {
                while (true)
                {
                    var result = _consumer.Consume();

                    // TODO: Implement envelope unwrapping
                    // TODO: Validate required headers
                    // TODO: Deserialize protobuf payload
                    // TODO: Implement idempotency check
                    // TODO: Process event
                    // TODO: Handle errors and retry logic

                    _consumer.Commit(result);
                }
            }
            catch (OperationCanceledException)
            {
                // Graceful shutdown
            }
            finally
            {
                _consumer.Close();
            }
        }

        public void Dispose()
        {
            _consumer?.Dispose();
        }
    }
}
