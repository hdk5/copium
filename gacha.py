import random
from decimal import Decimal
from enum import Enum, auto


class GachaMachine:
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

    class PullResult(Enum):
        TRASH = auto()
        SSR = auto()
        BANNER = auto()

    SSR_BASE_RATE = Decimal("0.02")

    SSR_PITY_MIN_PULLS = 50
    SSR_PITY_RATE_STEP = Decimal("0.025")

    BANNER_BASE_RATE = Decimal("0.5")
    BANNER_PITY_MIN_PULLS = 2

    def __init__(self):
        self.ssr_pity_counter = 0
        self.banner_pity_counter = 0

    @property
    def ssr_rate(self):
        return self.SSR_BASE_RATE + self.SSR_PITY_RATE_STEP * max(
            0, self.ssr_pity_counter - self.SSR_PITY_MIN_PULLS + 1
        )

    @property
    def banner_rate(self):
        return (
            self.BANNER_BASE_RATE
            if self.banner_pity_counter < self.BANNER_PITY_MIN_PULLS
            else 1
        )

    def pull(self):
        is_ssr_pull = random.random() < self.ssr_rate

        if is_ssr_pull:
            self.ssr_pity_counter = 0

            is_banner_pull = random.random() < self.banner_rate

            if is_banner_pull:
                self.banner_pity_counter = 0
                pull_result = self.PullResult.BANNER

            else:
                self.banner_pity_counter += 1
                pull_result = self.PullResult.SSR

        else:
            self.ssr_pity_counter += 1
            pull_result = self.PullResult.TRASH

        return pull_result

    def pull_while(self, expected, amount):
        total_pulls = 0
        expected_pulls = 0

        while True:
            pull_result = self.pull()
            total_pulls += 1

            if pull_result == expected:
                expected_pulls += 1

                if expected_pulls >= amount:
                    break

        return total_pulls
