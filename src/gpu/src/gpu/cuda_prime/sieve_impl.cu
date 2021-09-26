#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "sieve_impl.cuh"
#include "sieve.hpp"
#include "sieve_small_prime_constants.cuh"

#include <cuda.h>
#include <stdio.h>
#include <math.h>
#include <inttypes.h>


#define checkCudaErrors(call)                                \
  do {                                                        \
    cudaError_t err = call;                                   \
    if (err != cudaSuccess) {                                 \
      printf("CUDA error at %s %d: %s\n", __FILE__, __LINE__, \
             cudaGetErrorString(err));                        \
      exit(EXIT_FAILURE);                                     \
    }                                                         \
  } while (0)

namespace nexusminer {
    namespace gpu {

        __device__ void cuda_chain_push_back(CudaChain& chain, uint16_t offset);
        __device__ void cuda_chain_open(CudaChain& chain, uint64_t base_offset);

        __device__ const unsigned int sieve30_offsets[]{ 1,7,11,13,17,19,23,29 };

        __device__ const unsigned int sieve30_gaps[]{ 6,4,2,4,2,4,6,2 };

        __device__ const unsigned int sieve30_index[]
        { 0,0,1,1,1,1,1, 1, 2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7 };  //reverse lookup table (offset mod 30 to index)

        __device__ const unsigned int sieve120_index[]
        {    0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 
             8, 8, 9, 9, 9, 9, 9, 9,10,10,10,10,11,11,12,12,12,12,13,13,14,14,14,14,15,15,15,15,15,15,
            16,16,17,17,17,17,17,17,18,18,18,18,19,19,20,20,20,20,21,21,22,22,22,22,23,23,23,23,23,23,
            24,24,25,25,25,25,25,25,26,26,26,26,27,27,28,28,28,28,29,29,30,30,30,30,31,31,31,31,31,31
        };  //reverse lookup table (offset mod 120 to index)


        __device__  const Cuda_sieve::sieve_word_t unset_bit_mask[]{
            ~(1u << 0),  ~(1u << 1),  ~(1u << 2),  ~(1u << 3),  ~(1u << 4),  ~(1u << 5),  ~(1u << 6),  ~(1u << 7), 
            ~(1u << 8),  ~(1u << 9),  ~(1u << 10), ~(1u << 11), ~(1u << 12), ~(1u << 13), ~(1u << 14), ~(1u << 15),
            ~(1u << 16), ~(1u << 17), ~(1u << 18), ~(1u << 19), ~(1u << 20), ~(1u << 21), ~(1u << 22), ~(1u << 23),
            ~(1u << 24), ~(1u << 25), ~(1u << 26), ~(1u << 27), ~(1u << 28), ~(1u << 29), ~(1u << 30), ~(1u << 31)
        };
        
        // cross off small primes.  These primes hit the sieve often.  We iterate through the sieve words and cross them off using 
        // precalculated constants.  start is offset from the sieve start 
        __global__ void sieveSmallPrimes(Cuda_sieve::sieve_word_t* sieve, uint64_t start, uint32_t* small_prime_offsets)
        {

            uint64_t num_blocks = gridDim.x;
            uint64_t num_threads = blockDim.x;
            uint64_t block_id = blockIdx.x;
            uint64_t index = block_id * num_threads + threadIdx.x;
            uint64_t stride = num_blocks * num_threads;

            const uint32_t increment = Cuda_sieve::m_sieve_word_range;

            //#pragma unroll
            for (uint64_t i = index; i < Cuda_sieve::m_sieve_total_size; i += stride) 
            {
                
                //the offset for the sieve word in process
                uint64_t inc = i * increment;
                //get the correct rotation for the prime mask
                //primes for reference 7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101
                //                     1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22, 23  

                uint16_t index7 = (start + small_prime_offsets[0] + inc) % 7;
                uint16_t index11 = (start + small_prime_offsets[1] + inc) % 11;
                uint16_t index13 = (start + small_prime_offsets[2] + inc) % 13;
                uint16_t index17 = (start + small_prime_offsets[3] + inc) % 17;
                uint16_t index19 = (start + small_prime_offsets[4] + inc) % 19;
                uint16_t index23 = (start + small_prime_offsets[5] + inc) % 23;
                uint16_t index29 = (start + small_prime_offsets[6] + inc) % 29;
                uint16_t index31 = (start + small_prime_offsets[7] + inc) % 31;
                uint16_t index37 = (start + small_prime_offsets[8] + inc) % 37;
                uint16_t index41 = (start + small_prime_offsets[9] + inc) % 41;
                uint16_t index43 = (start + small_prime_offsets[10] + inc) % 43;
                uint16_t index47 = (start + small_prime_offsets[11] + inc) % 47;
                uint16_t index53 = (start + small_prime_offsets[12] + inc) % 53;
                uint16_t index59 = (start + small_prime_offsets[13] + inc) % 59;
                uint16_t index61 = (start + small_prime_offsets[14] + inc) % 61;
                uint16_t index67 = (start + small_prime_offsets[15] + inc) % 67;
                uint16_t index71 = (start + small_prime_offsets[16] + inc) % 71;
                uint16_t index73 = (start + small_prime_offsets[17] + inc) % 73;
                uint16_t index79 = (start + small_prime_offsets[18] + inc) % 79;
                uint16_t index83 = (start + small_prime_offsets[19] + inc) % 83;
                uint16_t index89 = (start + small_prime_offsets[20] + inc) % 89;
                uint16_t index97 = (start + small_prime_offsets[21] + inc) % 97;
                uint16_t index101 = (start + small_prime_offsets[22] + inc) % 101;

               

                //apply the mask.  the mask for the first prime 7 is also used to initialize the sieve (hence no &).
                Cuda_sieve::sieve_word_t word;
                word = p7[index7];
                word &= p11[index11];
                word &= p13[index13];
                word &= p17[index17];
                word &= p19[index19];
                word &= p23[index23];
                word &= p29[index29];
                word &= p31[index31];
                word &= p37[index37];
                word &= p41[index41];
                word &= p43[index43];
                word &= p47[index47];
                word &= p53[index53];
                word &= p59[index59];
                word &= p61[index61];
                word &= p67[index67];
                word &= p71[index71];
                word &= p73[index73];
                word &= p79[index79];
                word &= p83[index83];
                word &= p89[index89];
                word &= p97[index97];
                word &= p101[index101];

                //save to global memory
                sieve[i] = word;

            }
        }
        
        //get the nth bit from the sieve.
        __device__ __forceinline__ bool get_bit(uint64_t bit_position, Cuda_sieve::sieve_word_t* sieve)
        {
            const uint32_t sieve_bits_per_word = Cuda_sieve::m_sieve_word_byte_count * 8;
            
            uint64_t word = bit_position / sieve_bits_per_word;
            unsigned bit_position_in_word = bit_position % sieve_bits_per_word;
            return ((sieve[word] >> bit_position_in_word) & 1) == 1;

        }

        //search the sieve for chains that meet the minimum length requirement.  
        __global__ void find_chain_kernel(Cuda_sieve::sieve_word_t* sieve, CudaChain* chains, uint32_t* chain_index, uint64_t sieve_start_offset)
        {

            //const uint64_t sieve_size = Cuda_sieve::m_sieve_total_size;
            const uint32_t sieve_bits_per_word = Cuda_sieve::m_sieve_word_byte_count * 8;
            const uint64_t sieve_total_bits = Cuda_sieve::m_sieve_total_size * sieve_bits_per_word;

            
            uint64_t num_blocks = gridDim.x;
            uint64_t num_threads = blockDim.x;
            uint64_t block_id = blockIdx.x;
            uint64_t index = block_id * num_threads + threadIdx.x;
            uint64_t stride = num_blocks * num_threads;
            unsigned int sieve_offset;
            unsigned int gap;
            uint64_t chain_start, prime_candidate_offset;
            
            
            if (index == 0)
                *chain_index = 0;
            __syncthreads();
           
            //search each sieve location for a possible chain
            for (uint64_t i = index; i < sieve_total_bits; i += stride)
            {
                if (i < sieve_total_bits)
                {
                    //gross checks to ensure its possible to form a chain
                    uint64_t word = i / sieve_bits_per_word;
                    if (sieve[word] == 0)
                        return;
                    if (word < Cuda_sieve::m_sieve_total_size - 1)
                    {
                        int popc = __popc(sieve[word]) + __popc(sieve[word + 1]);
                        if (popc < Cuda_sieve::m_min_chain_length)
                            return;
                    }

                    //chain must start with a prime
                    if (!get_bit(i, sieve))
                    {
                        return;
                    }
                    //search left for another prime less than max gap away
                    gap = 0;
                    int64_t j = i;
                    j--;
                    while (j >= 0 && gap <= maxGap)
                    {
                        gap += sieve30_gaps[j % 8];
                        if (gap <= maxGap && get_bit(j, sieve))
                        {
                            //there is a valid element to the left.  this is not the first element in a chain. abort.
                            return;
                        }
                        
                        j--;
                    }
                   
                    //this is the start of a possible chain.  search right
                    //where are we in the wheel
                    sieve_offset = sieve30_offsets[i % 8u];
                    chain_start = sieve_start_offset + i / 8 * 30 + sieve_offset;
                    CudaChain current_chain;
                    cuda_chain_open(current_chain, chain_start);
                    gap = 0;
                    j = i;
                    j++;
                    while (j < sieve_total_bits && gap <= maxGap)
                    {
                        gap += sieve30_gaps[j % 8u];
                        if (gap <= maxGap && get_bit(j, sieve))
                        {
                            //another possible candidate.  add it to the chain
                            gap = 0;
                            sieve_offset = sieve30_offsets[j % 8u];
                            prime_candidate_offset = sieve_start_offset + j / 8 * 30 + sieve_offset;
                            cuda_chain_push_back(current_chain, static_cast<uint16_t>(prime_candidate_offset - chain_start));
                        }
                        j++;
                    }
                    //we reached the end of the chain.  check if it meets the length requirement
                    if (current_chain.m_offset_count >= Cuda_sieve::m_min_chain_length)
                    {
                        //increment the chain list index
                        uint32_t chain_idx = atomicInc(chain_index, Cuda_sieve::m_max_chains);
                        //copy the current chain to the global list
                        chains[chain_idx] = current_chain;
                    }
                }
            }
            

        }

       
        //return the offset from x to the next integer multiple of n greater than x that is not divisible by 2, 3, or 5.  
        //x must be a multiple of the primorial 30 and n must be a prime greater than 5.
        template <typename T1, typename T2>
        __device__ T2 get_offset_to_next_multiple(T1 x, T2 n)
        {
            T2 m = n - static_cast<T2>(x % n);
            if (m % 2 == 0)
            {
                m += n;
            }
            while (m % 3 == 0 || m % 5 == 0)
            {
                m += 2 * n;
            }
            return m;
        }

        //medium prime seive
        __global__ void do_sieve(uint64_t sieve_start_offset, uint32_t* sieving_primes, uint32_t sieving_prime_count,
            uint32_t* starting_multiples, uint8_t* prime_mod_inverses, Cuda_sieve::sieve_word_t* sieve_results, uint32_t* multiples,
            uint8_t* wheel_indices, unsigned long long* prime_candidate_count)
        {

            const uint32_t segment_size = Cuda_sieve::m_kernel_sieve_size_bytes * Cuda_sieve::m_sieve_byte_range;

            //local shared copy of the sieve
            __shared__ Cuda_sieve::sieve_word_t sieve[Cuda_sieve::m_kernel_sieve_size_words];

            uint64_t block_id = blockIdx.x;
            uint64_t index = threadIdx.x;
            uint64_t stride = blockDim.x;
           
            const uint64_t segments = Cuda_sieve::m_kernel_segments_per_block;
            uint64_t sieve_results_index = block_id * Cuda_sieve::m_kernel_sieve_size_words_per_block;
            unsigned long long count = 0;

            //each block sieves a different region
            uint64_t start_offset = sieve_start_offset + block_id * Cuda_sieve::m_kernel_sieve_size_words_per_block * Cuda_sieve::m_sieve_word_range;
            
            unsigned int wheel_index;
            unsigned int next_wheel_gap;
            uint64_t j;
            uint64_t k;
            for (int s = 0; s < segments; s++)
            {
                
                //everyone in the block initialize part of the shared sieve
                for (int j1 = index; j1 < Cuda_sieve::m_kernel_sieve_size_words; j1 += stride)
                {
                    sieve[j1] = ~0;
                }

                __syncthreads();
                for (uint32_t i = index; i < sieving_prime_count; i += stride)
                {
                    
                    k = sieving_primes[i];
                    //get aligned to this region
                    if (s == 0)
                    {
                        j = starting_multiples[i];
                        //the first time through we need to calculate the starting offsets
                        if (start_offset >= j)
                            j = get_offset_to_next_multiple(start_offset - j, sieving_primes[i]);
                        else
                            j -= start_offset;
                            
                        //where are we in the wheel
                        wheel_index = sieve30_index[(prime_mod_inverses[i] * j) % 30];
                    }
                    else
                    {
                        j = multiples[block_id* sieving_prime_count +i];
                        wheel_index = wheel_indices[block_id * sieving_prime_count + i];
                    }
                    next_wheel_gap = sieve30_gaps[wheel_index];
                        
                    while (j < segment_size)
                    {
                        //cross off a multiple of the sieving prime
                        uint64_t sieve_index = j / Cuda_sieve::m_sieve_word_range;
                        Cuda_sieve::sieve_word_t bitmask = ~(static_cast<Cuda_sieve::sieve_word_t>(1) <<
                            (sieve30_index[j % 30] + (8 * (j/Cuda_sieve::m_sieve_byte_range % Cuda_sieve::m_sieve_word_byte_count))));
                        
                        //using this lookup table is a bit slower than the calculated version.
                        //Cuda_sieve::sieve_word_t bitmask2 = unset_bit_mask[sieve120_index[j % 120u]];
                        
                        //printf("%" PRIu64 " %u\n", j, bitmask);
                            
                        atomicAnd(&sieve[sieve_index], bitmask);
                        //sieve[sieve_index] &= ~static_cast<unsigned int>(~unset_bit_mask[j % 30]) << (j % 4);
                        //increment the next multiple of the current prime (rotate the wheel).
                        j += k * next_wheel_gap;
                        wheel_index = (wheel_index + 1u) % 8u;
                        next_wheel_gap = sieve30_gaps[wheel_index];
                    }
                    //save the starting multiple and wheel index for the next segment
                    multiples[block_id * sieving_prime_count + i] = j - segment_size;
                    wheel_indices[block_id * sieving_prime_count + i] = wheel_index;
                    
                }
                __syncthreads();
                

                //merge the sieve results back to global memory
                
                for (uint32_t j2 = index; j2 < Cuda_sieve::m_kernel_sieve_size_words; j2 += stride)
                {
                    if (j2 < Cuda_sieve::m_kernel_sieve_size_words)
                    {
                        sieve_results[sieve_results_index + j2] &= sieve[j2];
                        //count prime candidates
                        //__popcll is required if sieve type is uint64_t.  __popc is specified for uint32_t but seems to have no significant impact on performance
                        count += __popcll(sieve_results[sieve_results_index + j2]);

                    }
                }
                
                sieve_results_index += Cuda_sieve::m_kernel_sieve_size_words;
            }
            //update the global candidate count
             atomicAdd(prime_candidate_count, count);
            
        }

        void Cuda_sieve_impl::run_small_prime_sieve(uint64_t sieve_start_offset)
        {
            const int threads = 256;
            const int blocks = (Cuda_sieve::m_sieve_total_size + threads - 1)/threads;
            
            sieveSmallPrimes << <blocks, threads >> > (d_sieve, sieve_start_offset, d_small_prime_offsets);

            checkCudaErrors(cudaDeviceSynchronize());
        }

        void Cuda_sieve_impl::run_sieve(uint64_t sieve_start_offset)
        {
            m_sieve_start_offset = sieve_start_offset;
            
            do_sieve <<<Cuda_sieve::m_num_blocks, Cuda_sieve::m_threads_per_block >>> (sieve_start_offset, d_sieving_primes, m_sieving_prime_count,
                d_starting_multiples, d_prime_mod_inverses, d_sieve, d_multiples, d_wheel_indices, d_prime_candidate_count);

            checkCudaErrors(cudaDeviceSynchronize());
        }

        void Cuda_sieve_impl::get_sieve(Cuda_sieve::sieve_word_t sieve[])
        {
            checkCudaErrors(cudaMemcpy(sieve, d_sieve, Cuda_sieve::m_sieve_total_size * sizeof(*d_sieve), cudaMemcpyDeviceToHost));

        }

        void Cuda_sieve_impl::get_prime_candidate_count(uint64_t& prime_candidate_count)
        {
            checkCudaErrors(cudaMemcpy(&prime_candidate_count, d_prime_candidate_count, sizeof(*d_prime_candidate_count), cudaMemcpyDeviceToHost));

        }

        void Cuda_sieve_impl::find_chains(CudaChain chains[], uint32_t& chain_count)
        {
            const int sieve_threads = 256;
            const int checks_per_block = 1;
            const uint32_t sieve_bits_per_word = Cuda_sieve::m_sieve_word_byte_count * 8;
            const uint64_t sieve_total_bits = Cuda_sieve::m_sieve_total_size * sieve_bits_per_word;
            const int sieve_blocks = (sieve_total_bits /checks_per_block + sieve_threads - 1)/ sieve_threads;
            
            //run the kernel
            find_chain_kernel << <sieve_blocks, sieve_threads >> > (d_sieve, d_chains, d_chain_index, m_sieve_start_offset);

            checkCudaErrors(cudaDeviceSynchronize());
            checkCudaErrors(cudaMemcpy(&chain_count, d_chain_index, sizeof(*d_chain_index), cudaMemcpyDeviceToHost));
            checkCudaErrors(cudaMemcpy(chains, d_chains, chain_count * sizeof(*d_chains), cudaMemcpyDeviceToHost));
        }

        //allocate global memory and load values used by the sieve to the gpu 
        void Cuda_sieve_impl::load_sieve(uint32_t primes[], uint32_t prime_count, uint32_t starting_multiples_host[],
            uint8_t prime_mod_inverses_host[], uint32_t small_prime_offsets[], uint32_t sieve_size, uint16_t device)
        {
          
            m_sieving_prime_count = prime_count;
            checkCudaErrors(cudaSetDevice(device));
            //allocate memory on the gpu
            checkCudaErrors(cudaMalloc(&d_sieving_primes, prime_count * sizeof(*d_sieving_primes)));
            checkCudaErrors(cudaMalloc(&d_starting_multiples, prime_count * sizeof(*d_starting_multiples)));
            checkCudaErrors(cudaMalloc(&d_prime_mod_inverses, prime_count * sizeof(*d_prime_mod_inverses)));
            checkCudaErrors(cudaMalloc(&d_small_prime_offsets, Cuda_sieve::m_small_prime_count * sizeof(*d_small_prime_offsets)));
            checkCudaErrors(cudaMalloc(&d_sieve, sieve_size * sizeof(*d_sieve)));
            checkCudaErrors(cudaMalloc(&d_multiples, prime_count * Cuda_sieve::m_num_blocks * sizeof(*d_multiples)));
            checkCudaErrors(cudaMalloc(&d_wheel_indices, prime_count * Cuda_sieve::m_num_blocks * sizeof(*d_wheel_indices)));
            checkCudaErrors(cudaMalloc(&d_chains, Cuda_sieve::m_max_chains * sizeof(*d_chains)));
            checkCudaErrors(cudaMalloc(&d_chain_index, sizeof(*d_chain_index)));
            checkCudaErrors(cudaMalloc(&d_prime_candidate_count, sizeof(*d_prime_candidate_count)));


            //copy data to the gpu
            checkCudaErrors(cudaMemcpy(d_sieving_primes, primes, prime_count * sizeof(*d_sieving_primes), cudaMemcpyHostToDevice));
            checkCudaErrors(cudaMemcpy(d_starting_multiples, starting_multiples_host, prime_count * sizeof(*d_starting_multiples), cudaMemcpyHostToDevice));
            checkCudaErrors(cudaMemcpy(d_small_prime_offsets, small_prime_offsets, Cuda_sieve::m_small_prime_count * sizeof(*d_small_prime_offsets), cudaMemcpyHostToDevice));
            checkCudaErrors(cudaMemcpy(d_prime_mod_inverses, prime_mod_inverses_host, prime_count * sizeof(*d_prime_mod_inverses), cudaMemcpyHostToDevice));
            checkCudaErrors(cudaMemset(d_chain_index, 0, sizeof(*d_chain_index)));
            checkCudaErrors(cudaMemset(d_prime_candidate_count, 0, sizeof(*d_prime_candidate_count)));


        }

        void Cuda_sieve_impl::free_sieve()
        {
            checkCudaErrors(cudaFree(d_sieving_primes));
            checkCudaErrors(cudaFree(d_starting_multiples));
            checkCudaErrors(cudaFree(d_wheel_indices));
            checkCudaErrors(cudaFree(d_multiples));
            checkCudaErrors(cudaFree(d_prime_mod_inverses));
            checkCudaErrors(cudaFree(d_sieve));
            checkCudaErrors(cudaFree(d_chains));
            checkCudaErrors(cudaFree(d_chain_index));
        }
    }
}