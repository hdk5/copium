"""
Modeled after Alchemy Stars gacha system.

Rules:
1. Banner has one limited SSR character;
2. Initial SSR rate is 2%;
3. After 50 failed SSR pulls, SSR rate is increased by 2.5% each pull;
4. After pulling an SSR, SSR rate is reset back to initial;
5. Banner rate is 50% (out of SSR rate);
6. After 2 failed banner pulls, banner unit is guaranteed on next SSR pull.
"""

import numpy as np

cimport cython
cimport numpy as np
from cpython.pycapsule cimport PyCapsule_GetPointer
from numpy.random cimport bitgen_t


cdef double calc_rate(double base, unsigned pity_min, double pity_step, unsigned pity_counter):
    cdef double rate = base + pity_step * max(
        0, pity_counter - pity_min + 1
    )
    return max(0., min(rate, 1.))


_rng = np.random.PCG64DXSM()
cdef bitgen_t* rng = <bitgen_t*> PyCapsule_GetPointer(
    _rng.capsule,
    "BitGenerator",
)


cdef double rand():
    return rng.next_double(rng.state)


cpdef enum PullResult:
    TRASH = 0
    SSR = 1
    BANNER = 2


cdef class GachaMachine:

    cdef double SSR_BASE_RATE

    cdef unsigned SSR_PITY_MIN_PULLS
    cdef double SSR_PITY_RATE_STEP

    cdef double BANNER_BASE_RATE
    cdef unsigned BANNER_PITY_MIN_PULLS

    cdef unsigned int ssr_pity_counter
    cdef unsigned int banner_pity_counter
    cdef bitgen_t *rng

    def __cinit__(self):
        self.SSR_BASE_RATE = 0.02
        self.SSR_PITY_MIN_PULLS = 50
        self.SSR_PITY_RATE_STEP = 0.025
        self.BANNER_BASE_RATE = 0.5
        self.BANNER_PITY_MIN_PULLS = 2

    def __init__(self):
        self.reset()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef make_pulls_distribution(
        self,
        unsigned int samples,
        PullResult expected,
        unsigned int amount,
    ):
        cdef unsigned int[::1] results = np.zeros(samples, dtype=np.uintc)

        cdef int i
        for i in range(samples):
            self.reset()
            results[i] = self.pull_until(expected, amount)

        return np.asarray(results, dtype=np.uintc)

    cpdef reset(self):
        self.ssr_pity_counter = 0
        self.banner_pity_counter = 0

    cpdef double calc_ssr_rate(self):
        return calc_rate(
            self.SSR_BASE_RATE,
            self.SSR_PITY_MIN_PULLS,
            self.SSR_PITY_RATE_STEP,
            self.ssr_pity_counter,
        )

    cpdef double calc_banner_rate(self):
        return calc_rate(
            self.BANNER_BASE_RATE,
            self.BANNER_PITY_MIN_PULLS,
            1,
            self.banner_pity_counter,
        )

    cpdef PullResult pull(self):
        cdef PullResult pull_result
        cdef bint is_ssr_pull, is_banner_pull

        is_ssr_pull = rand() < self.calc_ssr_rate()

        if is_ssr_pull:
            self.ssr_pity_counter = 0

            is_banner_pull = rand() < self.calc_banner_rate()

            if is_banner_pull:
                self.banner_pity_counter = 0
                pull_result = PullResult.BANNER

            else:
                self.banner_pity_counter += 1
                pull_result = PullResult.SSR

        else:
            self.ssr_pity_counter += 1
            pull_result = PullResult.TRASH

        return pull_result

    cpdef unsigned int pull_until(self, PullResult expected, unsigned int amount):
        cdef unsigned int total_pulls = 0
        cdef unsigned int expected_pulls = 0
        cdef PullResult pull_result

        while expected_pulls < amount:
            pull_result = self.pull()
            total_pulls += 1

            if pull_result == expected:
                expected_pulls += 1

        return total_pulls
