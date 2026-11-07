import os

import redis

ENABLED = os.getenv("CACHE_ENABLED", "false").lower() == "true"
REDIS_URL = os.getenv("REDIS_URL", "")
TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "30"))

_client = (
    redis.Redis.from_url(REDIS_URL, socket_timeout=0.3, socket_connect_timeout=0.3)
    if ENABLED and REDIS_URL
    else None
)


def get(key: str):
    if _client is None:
        return None
    try:
        return _client.get(key)
    except redis.RedisError:
        return None


def set(key: str, value: bytes) -> None:
    if _client is None:
        return
    try:
        _client.set(key, value, ex=TTL_SECONDS)
    except redis.RedisError:
        pass
