#ifndef NEXUSMINER_GPU_CUDA_SIEVE_HPP
#define NEXUSMINER_GPU_CUDA_SIEVE_HPP

#include "cuda_chain.cuh"
//#include "fermat_test.hpp"
#include <stdint.h>
#include <memory>
#include <cmath>

namespace nexusminer {
	namespace gpu {

		class Cuda_sieve_impl;
		class Cuda_sieve
		{
		public:
			using sieve_word_t = uint32_t;
			static const int m_sieve_word_byte_count = sizeof(sieve_word_t);
			static const int m_kernel_sieve_size_bytes = 4096 * 8;  //this is the size of the sieve in bytes.  it should be a multiple of 8. 
			static const int m_kernel_sieve_size_words = m_kernel_sieve_size_bytes / m_sieve_word_byte_count;
			static const int m_kernel_segments_per_block = 64;  //number of times to run the sieve within a kernel call
			static const int m_kernel_sieve_size_words_per_block = m_kernel_sieve_size_words * m_kernel_segments_per_block;
			static const int m_threads_per_block = 1024;
			static const int m_num_blocks = 256;  //each block sieves part of the range
			static const uint64_t m_sieve_total_size = m_kernel_sieve_size_words_per_block * m_num_blocks; //size of the sieve in words
			static const int m_sieve_byte_range = 30;
			static const int m_sieve_word_range = m_sieve_byte_range * m_sieve_word_byte_count;
			static const uint64_t m_sieve_range = m_sieve_total_size * m_sieve_word_range;
			static const int m_estimated_chains_per_million = 30;
			static const uint32_t m_max_chains = 10*m_estimated_chains_per_million*m_sieve_range/1e6;
			static const uint32_t m_max_long_chains = 32;
			static const int m_min_chain_length = 8;

			static const int m_small_prime_count = 23;
			static const int m_small_primes[]; //array is defined in sieve.cu
//primes 7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,
//       1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22, 23,

			static const int m_large_prime_cutoff_index = 500000;  //prime 78500 is about 1e6.  prime 283145 is about 4e6
			static const int chain_histogram_max = 10;  
			

			Cuda_sieve();
			~Cuda_sieve();
			void load_sieve(uint32_t primes[], uint32_t prime_count, 
				uint32_t prime_mod_inverses[], uint32_t sieve_size, uint16_t device);
			void init_sieve(uint32_t starting_multiples[], uint32_t small_prime_offsets[]);
			void reset_stats();
			void free_sieve();
			void run_small_prime_sieve(uint64_t sieve_start_offset);
			void run_large_prime_sieve(uint64_t sieve_start_offset);
			void run_sieve(uint64_t sieve_start_offset);
			void find_chains();
			void clean_chains();
			void get_chains(CudaChain chains[], uint32_t& chain_count);
			void get_long_chains(CudaChain chains[], uint32_t& chain_count);

			void get_chain_count(uint32_t& chain_count);

			void get_chain_pointer(CudaChain*& chains_ptr, uint32_t*& chain_count_ptr);
			void get_sieve(sieve_word_t sieve[]);
			void get_prime_candidate_count(uint64_t& prime_candidate_count);
			void get_stats(uint32_t chain_histogram[], uint64_t& chain_count);

		private:
			std::unique_ptr<Cuda_sieve_impl> m_impl;
			

		};
	}
}

#endif