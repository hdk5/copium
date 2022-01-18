import numpy as np
cimport numpy as np
from cpython.pycapsule cimport PyCapsule_IsValid, PyCapsule_GetPointer
from numpy.random cimport bitgen_t


cdef class __PullResult:
    cdef public int TRASH
    cdef public int SSR
    cdef public int BANNER

    def __init__(self):
        self.TRASH = 0
        self.SSR = 1
        self.BANNER = 2


cdef class __GachaMachineCompanion:
    cdef public __PullResult PullResult

    cdef public double SSR_BASE_RATE

    cdef public int SSR_PITY_MIN_PULLS
    cdef public double SSR_PITY_RATE_STEP

    cdef public double BANNER_BASE_RATE
    cdef public int BANNER_PITY_MIN_PULLS

    def __init__(self):
        self.PullResult = __PullResult()

        self.SSR_BASE_RATE = 0.02

        self.SSR_PITY_MIN_PULLS = 50
        self.SSR_PITY_RATE_STEP = 0.025

        self.BANNER_BASE_RATE = 0.5
        self.BANNER_PITY_MIN_PULLS = 2


_GachaMachineCompanion = __GachaMachineCompanion()


cdef class GachaMachine:
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

    cdef public __GachaMachineCompanion companion

    cdef int ssr_pity_counter
    cdef int banner_pity_counter
    cdef bitgen_t *rng

    def __init__(self):
        self.companion = _GachaMachineCompanion

        self.ssr_pity_counter = 0
        self.banner_pity_counter = 0

        self.rng = <bitgen_t *> PyCapsule_GetPointer(
            np.random.PCG64DXSM().capsule,
            "BitGenerator",
        )

    cdef double _ssr_rate(self):
        return self.companion.SSR_BASE_RATE + self.companion.SSR_PITY_RATE_STEP * max(
            0, self.ssr_pity_counter - self.companion.SSR_PITY_MIN_PULLS + 1
        )

    cdef double _banner_rate(self):
        return (
            self.companion.BANNER_BASE_RATE
            if self.banner_pity_counter < self.companion.BANNER_PITY_MIN_PULLS
            else 1
        )

    cpdef double rand(self):
        return self.rng.next_double(self.rng.state)

    cpdef int pull(self):
        cdef int pull_result
        cdef bint is_ssr_pull, is_banner_pull

        is_ssr_pull = self.rand() < self._ssr_rate()

        if is_ssr_pull:
            self.ssr_pity_counter = 0

            is_banner_pull = self.rand() < self._banner_rate()

            if is_banner_pull:
                self.banner_pity_counter = 0
                pull_result = self.companion.PullResult.BANNER

            else:
                self.banner_pity_counter += 1
                pull_result = self.companion.PullResult.SSR

        else:
            self.ssr_pity_counter += 1
            pull_result = self.companion.PullResult.TRASH

        return pull_result

    cpdef int pull_while(self, int expected, int amount):
        cdef int total_pulls = 0
        cdef int expected_pulls = 0
        cdef int pull_result

        while True:
            pull_result = self.pull()
            total_pulls += 1

            if pull_result == expected:
                expected_pulls += 1

                if expected_pulls >= amount:
                    break

        return total_pulls
