#include "stats_collector.hpp"
#include "config.hpp"

namespace nexusminer
{
Stats_collector::Stats_collector(Config& config)
: m_config{config}
{
    for(auto& worker_config : m_config.get_worker_config())
    {
        if(m_config.get_mining_mode() == Config::HASH)
        {
            m_workers.push_back(Stats_hash{});
        }
        else
        {
            m_workers.push_back(Stats_prime{});
        }
    }
}

void Stats_collector::update_worker_stats(std::uint16_t internal_worker_id, Stats_hash const& stats)
{
    assert(m_config.get_mining_mode() == Config::HASH);

    auto& hash_stats = std::get<Stats_hash>(m_workers[internal_worker_id]);
    hash_stats += stats;
}

void Stats_collector::update_worker_stats(std::uint16_t internal_worker_id, Stats_prime const& stats)
{
    assert(m_config.get_mining_mode() == Config::PRIME);
    
    auto& prime_stats = std::get<Stats_prime>(m_workers[internal_worker_id]);
    prime_stats += stats;
}
}