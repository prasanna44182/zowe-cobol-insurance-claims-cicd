"""
Generate 100 sample insurance claims records for VSAM KSDS input.
Record layout: LRECL=100, fixed-length, key=positions 1-10 (policy number).

Fields:
  CLM-POLICY-NUMBER  X(10)    pos 1-10
  CLM-CLAIM-ID       X(08)    pos 11-18
  CLM-CLAIMANT-NAME  X(30)    pos 19-48
  CLM-CLAIM-DATE     9(08)    pos 49-56  (YYYYMMDD)
  CLM-CLAIM-TYPE     X(02)    pos 57-58  (MD/DN/DS/LF)
  CLM-CLAIM-AMOUNT   9(07)V99 pos 59-67  (7 digits + 2 decimal, no decimal point)
  CLM-COVERAGE-CODE  X(03)    pos 68-70
  CLM-STATUS         X(01)    pos 71     (N=new)
  FILLER             X(29)    pos 72-100
"""

import random

random.seed(42)

CLAIM_TYPES = ["MD", "DN", "DS", "LF"]
COVERAGE_CODES = ["HMO", "PPO", "EPO", "POS", "HDH", "GRP", "IND", "TRM"]

FIRST_NAMES = [
    "JAMES", "MARY", "ROBERT", "PATRICIA", "JOHN", "JENNIFER", "MICHAEL",
    "LINDA", "DAVID", "ELIZABETH", "WILLIAM", "BARBARA", "RICHARD", "SUSAN",
    "JOSEPH", "JESSICA", "THOMAS", "SARAH", "CHARLES", "KAREN", "DANIEL",
    "LISA", "MATTHEW", "NANCY", "ANTHONY", "BETTY", "MARK", "MARGARET",
    "DONALD", "SANDRA", "STEVEN", "ASHLEY", "PAUL", "DOROTHY", "ANDREW",
    "KIMBERLY", "JOSHUA", "EMILY", "KENNETH", "DONNA", "KEVIN", "MICHELLE",
    "BRIAN", "CAROL", "GEORGE", "AMANDA", "TIMOTHY", "MELISSA", "RONALD",
    "DEBORAH"
]

LAST_NAMES = [
    "SMITH", "JOHNSON", "WILLIAMS", "BROWN", "JONES", "GARCIA", "MILLER",
    "DAVIS", "RODRIGUEZ", "MARTINEZ", "HERNANDEZ", "LOPEZ", "GONZALEZ",
    "WILSON", "ANDERSON", "THOMAS", "TAYLOR", "MOORE", "JACKSON", "MARTIN",
    "LEE", "PEREZ", "THOMPSON", "WHITE", "HARRIS", "SANCHEZ", "CLARK",
    "RAMIREZ", "LEWIS", "ROBINSON", "WALKER", "YOUNG", "ALLEN", "KING",
    "WRIGHT", "SCOTT", "TORRES", "NGUYEN", "HILL", "FLORES", "GREEN",
    "ADAMS", "NELSON", "BAKER", "HALL", "RIVERA", "CAMPBELL", "MITCHELL",
    "CARTER", "ROBERTS"
]

records = []

for i in range(1, 101):
    policy_no = f"POL{i:07d}"
    claim_id = f"CLM{i:05d}"
    first = random.choice(FIRST_NAMES)
    last = random.choice(LAST_NAMES)
    name = f"{first} {last}"

    year = random.choice([2024, 2025, 2026])
    month = random.randint(1, 12)
    day = random.randint(1, 28)
    claim_date = f"{year}{month:02d}{day:02d}"

    claim_type = random.choice(CLAIM_TYPES)

    if i <= 85:
        if i % 10 == 0:
            amount_dollars = random.randint(50001, 250000)
        elif i % 5 == 0:
            amount_dollars = random.randint(10000, 50000)
        else:
            amount_dollars = random.randint(100, 9999)
        amount_cents = random.randint(0, 99)
    else:
        amount_dollars = 0
        amount_cents = 0

    amount_str = f"{amount_dollars:07d}{amount_cents:02d}"

    coverage = random.choice(COVERAGE_CODES)
    status = "N"

    if i <= 85:
        valid = True
    else:
        valid = False

    if not valid:
        defect = random.choice(["blank_policy", "blank_claim", "bad_type",
                                "zero_amount", "bad_date"])
        if defect == "blank_policy":
            policy_no = "          "
        elif defect == "blank_claim":
            claim_id = "        "
        elif defect == "bad_type":
            claim_type = "XX"
        elif defect == "zero_amount":
            amount_str = "000000000"
        elif defect == "bad_date":
            claim_date = "00000000"

    rec = (
        f"{policy_no:<10}"
        f"{claim_id:<8}"
        f"{name:<30}"
        f"{claim_date}"
        f"{claim_type}"
        f"{amount_str}"
        f"{coverage}"
        f"{status}"
        f"{' ' * 29}"
    )

    assert len(rec) == 100, f"Record {i} length={len(rec)}, expected 100"
    records.append(rec)

with open("CLMSDATA.txt", "w") as f:
    for rec in records:
        f.write(rec + "\n")

valid_count = sum(1 for r in records if r[0:10].strip() and r[10:18].strip()
                  and r[56:58] in ("MD","DN","DS","LF")
                  and int(r[48:56]) > 0 and int(r[58:67]) > 0)
reject_count = 100 - valid_count

high_value = sum(1 for r in records if int(r[58:65]) > 50000
                 and r[0:10].strip() and r[56:58] in ("MD","DN","DS","LF"))

print(f"Generated 100 records -> CLMSDATA.txt")
print(f"  Expected valid:  {valid_count}")
print(f"  Expected reject: {reject_count}")
print(f"  High-value (>$50K): {high_value}")
print(f"  Record length: {len(records[0])} bytes")
