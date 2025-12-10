using System.Data.SqlClient;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace RedisDemo01
{
    public class AdventureWorksDataService
    {
        private readonly string _connectionString;
        private readonly bool _isCachingEnabled;
    
        public AdventureWorksDataService(IConfiguration configuration)
        {
            _connectionString = configuration["ConnectionStrings:AdventureWorksDatabase"];
            _isCachingEnabled = (configuration["IsCachingEnabled"] == "true") ? true : false;
        }

        public string GetProducts()
        {
            string cacheKey = "productList";
            string results = "";
            if (_isCachingEnabled)
            {
                try
                {
                    results = RedisCacheService.GetCache(cacheKey);

                    if (!string.IsNullOrEmpty(results))
                    {
                        return results; // Return cached value
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Unable to retrieve cached data: {0}. Cache will be disabled!", ex.Message);
                    _isCachingEnabled = false;
                }
            }
            
            StringBuilder resultBuilder = new StringBuilder();

            try
            {
                using (SqlConnection connection = new SqlConnection(_connectionString))
                {
                    connection.Open();

                    string sql = "SELECT ProductId, Name FROM Production.Product";

                    using (SqlCommand command = new SqlCommand(sql, connection))
                    {
                        using (SqlDataReader reader = command.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                resultBuilder.AppendLine($"{reader["ProductId"]}, {reader["Name"]}");
                            }
                        }
                    }
                }

                results = resultBuilder.ToString();
                if (_isCachingEnabled)
                {
                    RedisCacheService.SetCache(cacheKey, results); // Cache the result
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Unable to retrieve data: {0}", ex.Message);
            }
            return results;
        }
    }
}