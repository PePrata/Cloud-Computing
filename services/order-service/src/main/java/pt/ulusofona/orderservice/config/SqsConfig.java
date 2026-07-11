package pt.ulusofona.orderservice.config;

import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsAsyncClient;

/**
 * Configuration class for the SQS producer.
 *
 * <p>Replaces the previous Kafka producer configuration (KafkaConfig). The
 * service now publishes events as plain SQS messages instead of records on a
 * Kafka log — each event type gets its own queue instead of its own topic, so
 * there is no need for the message-type header/mapping that the Kafka
 * JsonSerializer required.
 *
 * <p>The {@link SqsAsyncClient} resolves AWS credentials using the default
 * SDK credential chain (environment variables, or — in the deployed EC2 app
 * host — the instance profile via IMDS), so no access keys are configured
 * here or anywhere in this repository.
 *
 * @author Cloud Computing Course
 * @version 1.0.0
 * @since 1.0.0
 */
@Configuration
public class SqsConfig {

    @Value("${aws.region:us-east-1}")
    private String awsRegion;

    @Bean
    public SqsAsyncClient sqsAsyncClient() {
        return SqsAsyncClient.builder()
                .region(Region.of(awsRegion))
                .build();
    }

    @Bean
    public SqsTemplate sqsTemplate(SqsAsyncClient sqsAsyncClient) {
        return SqsTemplate.builder()
                .sqsAsyncClient(sqsAsyncClient)
                .build();
    }
}
