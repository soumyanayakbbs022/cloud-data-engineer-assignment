import pandas as pd
import random
import uuid
import os
from datetime import datetime, timedelta

# -----------------------------
# Configuration
# -----------------------------

TOTAL_ROWS = 100_000
ERROR_PERCENTAGE = 0.05
TOTAL_ERROR_ROWS = int(TOTAL_ROWS * ERROR_PERCENTAGE)

BATCH_FILES = [
    "batch_01.csv",
    "batch_02.csv",
    "batch_03.csv"
]

ROWS_PER_BATCH = TOTAL_ROWS // 3

STORE_IDS = [f"STR-{str(i).zfill(3)}" for i in range(1, 21)]

PRODUCT_IDS = [f"PRD-{str(i).zfill(4)}" for i in range(1, 501)]

# -----------------------------
# Create output directory
# -----------------------------

OUTPUT_DIR = "data/batches"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# -----------------------------
# Generate valid transaction
# -----------------------------

def generate_valid_transaction(ingestion_time):
    
    transaction_time = ingestion_time - timedelta(
        minutes=random.randint(1, 90)
    )

    quantity = random.randint(1, 5)

    unit_price = round(random.uniform(5, 500), 2)

    return {
        "transaction_id": str(uuid.uuid4()),
        "store_id": random.choice(STORE_IDS),
        "product_id": random.choice(PRODUCT_IDS),
        "quantity": str(quantity),
        "unit_price": str(unit_price),
        "transaction_time": transaction_time,
        "ingestion_time": ingestion_time
    }

# -----------------------------
# Generate base batch data
# -----------------------------

all_batches = []

base_ingestion_time = datetime.now()

for batch_num in range(3):

    batch_rows = []

    batch_ingestion_time = base_ingestion_time + timedelta(
        hours=batch_num
    )

    for _ in range(ROWS_PER_BATCH):

        transaction = generate_valid_transaction(
            batch_ingestion_time
        )

        batch_rows.append(transaction)

    random.shuffle(batch_rows)

    all_batches.append(batch_rows)

# -----------------------------
# Error allocation
# -----------------------------

duplicate_error_count = 1225
missing_product_count = 1275
invalid_quantity_count = 1281
invalid_price_count = 1219



# -----------------------------
# Inject missing product IDs
# -----------------------------

for _ in range(missing_product_count):

    batch = random.choice(all_batches)

    row = random.choice(batch)

    row["product_id"] = ""

# -----------------------------
# Inject invalid quantities
# -----------------------------

for _ in range(invalid_quantity_count):

    batch = random.choice(all_batches)

    row = random.choice(batch)

    row["quantity"] = random.choice(["0", "-3"])

# -----------------------------
# Inject invalid unit prices
# -----------------------------

for _ in range(invalid_price_count):

    batch = random.choice(all_batches)

    row = random.choice(batch)

    row["unit_price"] = random.choice(["N/A", "-1.00"])

# -----------------------------
# Inject late-arriving records
# -----------------------------

late_record_count = random.randint(200, 500)

for _ in range(late_record_count):

    batch = random.choice([all_batches[1], all_batches[2]])

    row = random.choice(batch)

    row["transaction_time"] = (
        row["ingestion_time"]
        - timedelta(hours=random.randint(3, 12))
    )

# -----------------------------
# Inject significantly late records
# -----------------------------

significantly_late_count = random.randint(100, 200)

for _ in range(significantly_late_count):

    row = random.choice(all_batches[2])

    row["transaction_time"] = (
        row["ingestion_time"]
        - timedelta(hours=random.randint(25, 72))
    )

# -----------------------------
# Normalize batch sizes
# -----------------------------

target_batch_size = (
    TOTAL_ROWS - duplicate_error_count
) // 3

normalized_batches = []

for batch in all_batches:

    if len(batch) > target_batch_size:
        batch = batch[:target_batch_size]

    elif len(batch) < target_batch_size:

        additional_rows_needed = (
            target_batch_size - len(batch)
        )

        for _ in range(additional_rows_needed):

            batch.append(
                generate_valid_transaction(
                    batch[0]["ingestion_time"]
                )
            )

    normalized_batches.append(batch)

all_batches = normalized_batches


# -----------------------------
# Inject duplicate transaction IDs
# -----------------------------

for _ in range(duplicate_error_count):

    source_row = random.choice(all_batches[0])

    duplicated_row = source_row.copy()

    target_batch = random.choice([
        all_batches[1],
        all_batches[2]
    ])

    duplicated_row["ingestion_time"] = (
    duplicated_row["ingestion_time"]
    + timedelta(minutes=random.randint(10, 90))
    )

    target_batch.append(duplicated_row)

# -----------------------------
# Export batch files
# -----------------------------

for idx, batch in enumerate(all_batches, start=1):

    file_name = f"batch_{idx:02d}.csv"

    df = pd.DataFrame(batch)

    df["source_batch"] = file_name

    file_path = os.path.join(
        OUTPUT_DIR,
        file_name
    )

    df.to_csv(file_path, index=False)

    print(
        f"{file_name} created with {len(df)} rows"
    )

print("\nData generation completed successfully.")

