package pt.ulusofona.productservice.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import io.awspring.cloud.sqs.annotation.SqsListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pt.ulusofona.productservice.event.OrderCreatedEvent;
import pt.ulusofona.productservice.event.OrderItemEvent;
import pt.ulusofona.productservice.model.Product;
import pt.ulusofona.productservice.repository.ProductRepository;

/**
 * SQS event consumer for order-related events.
 * 
 * <p>This service consumes messages from the SQS queue published by the Order
 * Service. It handles:
 * <ul>
 *   <li>OrderCreatedEvent - Updates product inventory when orders are created</li>
 * </ul>
 * 
 * <p>This demonstrates asynchronous, event-driven communication between microservices.
 * 
 * @author Cloud Computing Course
 * @version 1.0.0
 * @since 1.0.0
 * @see OrderCreatedEvent
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderEventConsumer {

    private final ProductRepository productRepository;

    /**
     * Consumes OrderCreatedEvent from SQS.
     * 
     * <p>This method is automatically invoked when a message is received on the
     * "order-created" queue. It updates the stock quantity for each product
     * in the order by subtracting the ordered quantity.
     * 
     * <p>Note: SQS queues have a single logical consumer group built in (unlike
     * Kafka, there is no separate {@code groupId} to configure) — each message
     * is delivered to and removed by exactly one consumer.
     * 
     * <p>Note: In a production system, you might want to implement idempotency
     * checks to handle duplicate events (SQS's at-least-once delivery can
     * redeliver a message more than once).
     * 
     * @param event The OrderCreatedEvent received from SQS
     * @apiNote This method uses a write transaction
     */
    @SqsListener("order-created")
    @Transactional
    public void handleOrderCreated(OrderCreatedEvent event) {
        log.info("Received OrderCreatedEvent for order ID: {}", event.getOrderId());

        try {
            for (OrderItemEvent item : event.getItems()) {
                Product product = productRepository.findById(item.getProductId())
                        .orElseThrow(() -> new RuntimeException(
                                "Product not found with ID: " + item.getProductId()));

                int newStock = product.getStockQuantity() - item.getQuantity();
                if (newStock < 0) {
                    log.warn("Insufficient stock for product {} (Order ID: {}). Current: {}, Requested: {}",
                            product.getName(), event.getOrderId(), product.getStockQuantity(), item.getQuantity());
                    // In production, you might want to publish a compensation event
                    continue;
                }

                product.setStockQuantity(newStock);
                productRepository.save(product);
                log.info("Updated stock for product {}: {} -> {} (Order ID: {})",
                        product.getName(), product.getStockQuantity() + item.getQuantity(),
                        newStock, event.getOrderId());
            }
        } catch (Exception e) {
            log.error("Error processing OrderCreatedEvent for order ID: {}", event.getOrderId(), e);
            // In production, you might want to send the event to a dead letter queue
        }
    }
}

