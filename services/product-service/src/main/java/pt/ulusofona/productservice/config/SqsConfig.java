package pt.ulusofona.productservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsAsyncClient;

/**
 * Configuration class for the SQS consumer client.
 *
 * <p>product-service only consumes events (it never publishes), so unlike
 * order-service it doesn't need an {@code SqsTemplate} bean — just the
 * underlying {@link SqsAsyncClient} that Spring Cloud AWS's
 * {@code @SqsListener} infrastructure uses to poll queues.
 *
 * <p>Credentials resolve via the default AWS SDK chain (environment
 * variables locally, or the EC2 instance profile via IMDS once deployed),
 * so nothing sensitive is configured here.
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
}
