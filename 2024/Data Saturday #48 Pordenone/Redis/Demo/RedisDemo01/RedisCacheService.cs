using System;
using StackExchange.Redis;

namespace RedisDemo01
{
    public class RedisCacheService
    {
        private static ConnectionMultiplexer _connectionMultiplexer;

        public RedisCacheService(ConnectionMultiplexer connectionMultiplexer)
        {
            _connectionMultiplexer = connectionMultiplexer;
        }

        public static void SetCache(string key, string value)
        {
            var db = _connectionMultiplexer.GetDatabase();
            db.StringSet(key, value);
        }

        public static string GetCache(string key)
        {
            var db = _connectionMultiplexer.GetDatabase();
            return db.StringGet(key);
        }
    }
}