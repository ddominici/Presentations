using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using System.Data.SqlClient;
using StackExchange.Redis;
using RedisDemo01;
using System;

var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

var serviceCollection = new ServiceCollection();
serviceCollection.AddSingleton<IConfiguration>(configuration);
serviceCollection.AddSingleton<ConnectionMultiplexer>(sp => 
    ConnectionMultiplexer.Connect(configuration["ConnectionStrings:Redis"]));
serviceCollection.AddTransient<SqlConnection>(sp => 
    new SqlConnection(configuration["ConnectionStrings:AdventureWorksDatabase"]));
serviceCollection.AddTransient<AdventureWorksDataService>();
serviceCollection.AddSingleton<RedisCacheService>();

var serviceProvider = serviceCollection.BuildServiceProvider();

// Application entry point
await RunApplicationAsync(serviceProvider);


// Example method to run application logic
async Task RunApplicationAsync(IServiceProvider serviceProvider)
{
    var cacheService = serviceProvider.GetService<RedisCacheService>();
    var dataService = serviceProvider.GetService<AdventureWorksDataService>();

    var start = DateTime.Now;
    Console.WriteLine("Program started at {0}", start);
    
    try
    {
        for (int i = 0; i < 10000; i++)
        {
            var result = dataService.GetProducts();
            Console.WriteLine("{0} records found!", result.Length);
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine("Unable to retrieve data: {0}", ex.Message);
    }
    
    var end = DateTime.Now;
    var diff = end - start;
    Console.WriteLine("Program started at {0}, duration {1}", end, diff);

}

