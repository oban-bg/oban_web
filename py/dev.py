import asyncio
import random
import signal
import sys
import traceback
from datetime import timedelta
from typing import Any

from faker import Faker
from oban import Oban, Snooze, worker

fake = Faker()

# Configuration constants (matching WebDev.Generator)
MIN_DELAY = 500
MAX_DELAY = 45_000
MIN_SLEEP = 300
MAX_SLEEP = 30_000
MIN_JOBS = 1
MAX_JOBS = 12
MAX_SCHEDULE = 120
DELAY_CHANCE = 30
ERRORS = [
    "Connection timeout",
    "Rate limit exceeded",
    "Invalid response format",
    "Service temporarily unavailable",
    "Authentication failed",
    "Resource not found",
]

# Shutdown event for graceful termination
shutdown_event = asyncio.Event()


async def random_process(min_sleep: int = MIN_SLEEP, max_sleep: int = MAX_SLEEP):
    """
    Simulate job execution with random outcomes.

    - 10% chance: snooze for 5-30 seconds
    - 15% chance: raise an error
    - 75% chance: succeed after random sleep
    """
    await asyncio.sleep(random.randint(min_sleep, max_sleep) / 1000)

    outcome = random.randint(1, 100)

    if outcome <= 10:
        snooze_time = random.randint(5, 30)
        return Snooze(snooze=snooze_time)
    elif outcome <= 25:
        raise Exception(random.choice(ERRORS))
    else:
        return None


# Workers


@worker(queue="inference")
class SentimentAnalyzer:
    @staticmethod
    def gen() -> dict[str, Any]:
        return {
            "text": fake.paragraph(),
            "model": random.choice(["bert-base", "roberta-large", "distilbert"]),
            "language": fake.language_code(),
        }

    async def process(self, job):
        return await random_process()


@worker(queue="etl", max_attempts=3)
class DataTransformer:
    @staticmethod
    def gen() -> dict[str, Any]:
        return {
            "source": random.choice(["postgres", "mysql", "mongodb", "s3", "redis"]),
            "destination": random.choice(["warehouse", "lake", "api", "cache"]),
            "batch_id": fake.uuid4(),
            "record_count": random.randint(100, 10000),
        }

    async def process(self, job):
        return await random_process()


@worker(queue="webhooks", max_attempts=10)
class WebhookDelivery:
    @staticmethod
    def gen() -> dict[str, Any]:
        return {
            "endpoint": fake.url(),
            "event_type": random.choice(
                ["user.created", "order.completed", "payment.received", "item.shipped"]
            ),
            "payload_id": fake.uuid4(),
        }

    async def process(self, job):
        return await random_process(min_sleep=100, max_sleep=5000)


@worker(queue="transcoding", max_attempts=3)
class ImageResizer:
    @staticmethod
    def gen() -> dict[str, Any]:
        return {
            "source_key": f"uploads/{fake.uuid4()}.{random.choice(['jpg', 'png', 'webp'])}",
            "sizes": random.sample([128, 256, 512, 1024, 2048], k=random.randint(2, 4)),
            "quality": random.randint(70, 95),
        }

    async def process(self, job):
        return await random_process(min_sleep=500, max_sleep=15000)


# Cron


@worker(queue="maintenance", cron="* * * * *")
class HealthPing:
    async def process(self, job):
        await asyncio.sleep(random.randint(10, 100) / 1000)


@worker(queue="inference", cron="*/5 * * * *")
class ModelWarmup:
    async def process(self, job):
        await asyncio.sleep(random.randint(100, 500) / 1000)


@worker(queue="maintenance", cron="*/15 * * * *")
class CacheCleanup:
    async def process(self, job):
        await asyncio.sleep(random.randint(200, 1000) / 1000)


@worker(queue="etl", cron="0 * * * *")
class HourlyAggregator:
    async def process(self, job):
        await asyncio.sleep(random.randint(500, 2000) / 1000)


REGULAR_WORKERS = [
    SentimentAnalyzer,
    DataTransformer,
    WebhookDelivery,
    ImageResizer,
]


class Generator:
    def __init__(self, oban: Oban):
        self.oban = oban
        self.tasks: list[asyncio.Task] = []

    async def start(self):
        for worker_class in REGULAR_WORKERS:
            task = asyncio.create_task(self._loop(worker_class))
            self.tasks.append(task)

    async def stop(self):
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        self.tasks.clear()

    async def _loop(self, worker_class: type):
        while not shutdown_event.is_set():
            try:
                delay = random.randint(MIN_DELAY, MAX_DELAY) / 1000
                await asyncio.sleep(delay)

                jobs = [
                    self._build(worker_class)
                    for _ in range(random.randint(MIN_JOBS, MAX_JOBS))
                ]

                await self.oban.enqueue_many(jobs)

            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Error generating {worker_class.__name__} jobs: {e}")

                traceback.print_exc()
                await asyncio.sleep(5)

    def _build(self, worker_class):
        schedule_in = (
            timedelta(seconds=random.randint(1, MAX_SCHEDULE))
            if random.randint(1, 100) <= DELAY_CHANCE
            else None
        )

        return worker_class.new(worker_class.gen(), schedule_in=schedule_in)


async def run():
    pool = await Oban.create_pool()

    oban = Oban(
        metrics=True,
        node="web-dev-py",
        pool=pool,
        queues={
            "inference": 20,
            "etl": 10,
            "webhooks": 20,
            "transcoding": 8,
            "maintenance": 2,
        },
    )

    generator = Generator(oban)

    loop = asyncio.get_running_loop()
    sigint_count = 0

    def handle_signal(signum: int):
        nonlocal sigint_count
        shutdown_event.set()

        if signum == signal.SIGTERM:
            print("\nReceived SIGTERM, shutting down...")
        elif signum == signal.SIGINT:
            sigint_count += 1
            if sigint_count == 1:
                print("\nShutting down... (press Ctrl+C again to force)")
            else:
                print("\nForcing exit...")
                sys.exit(1)

    loop.add_signal_handler(signal.SIGINT, lambda: handle_signal(signal.SIGINT))
    loop.add_signal_handler(signal.SIGTERM, lambda: handle_signal(signal.SIGTERM))

    print("Starting Python Oban workers...")
    print("Press Ctrl+C to stop\n")

    async with oban:
        await generator.start()
        await shutdown_event.wait()
        await generator.stop()

    print("Shutdown complete")


def main():
    asyncio.run(run())


if __name__ == "__main__":
    main()
