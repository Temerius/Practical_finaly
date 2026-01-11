#!/usr/bin/env python3
"""
Data Generator for Practical Task
Generates realistic data files with various data quality issues:
- Large files (>16GB) with skewed keys
- Missing data (nulls, empty fields)
- Corrupted data (malformed JSON, invalid types)
- Duplicates
- Outliers and invalid values
"""

import json
import os
import random
import sys
import copy
from datetime import datetime, timedelta, timezone
from faker import Faker
from pathlib import Path

fake = Faker()
random.seed(42)

# Configuration from environment or defaults
FILE_SIZE_GB = float(os.getenv("DATA_FILE_SIZE_GB", "16"))
NUM_LARGE_FILES = int(os.getenv("NUM_LARGE_FILES", "2"))
OUTPUT_DIR = os.getenv("DATA_OUTPUT_DIR", "./data")
CORRUPTION_RATE = float(os.getenv("CORRUPTION_RATE", "0.001"))  # 0.1% corrupted records
MISSING_DATA_RATE = float(os.getenv("MISSING_DATA_RATE", "0.05"))  # 5% missing fields
DUPLICATE_RATE = float(os.getenv("DUPLICATE_RATE", "0.02"))  # 2% duplicates
OUTLIER_RATE = float(os.getenv("OUTLIER_RATE", "0.01"))  # 1% outliers

# Device configuration for key skew
DEVICE_TYPES = ["sensor_A", "sensor_B", "camera", "thermo"]
# 80% of data from 10% of devices (heavy skew)
POPULAR_DEVICES = [f"dev_{i}" for i in range(1, 6)]  # dev_1 to dev_5
RARE_DEVICES = [f"dev_{i}" for i in range(6, 51)]  # dev_6 to dev_50

# For generating duplicates
generated_event_ids = set()


def generate_valid_record(record_counter):
    """Generate a valid record"""
    # Create key skew: 80% from popular devices, 20% from rare
    if random.random() < 0.8:
        device_id = random.choice(POPULAR_DEVICES)
    else:
        device_id = random.choice(RARE_DEVICES)
    
    device_type = random.choice(DEVICE_TYPES)
    
    # Generate timestamp within last 30 days
    days_ago = random.randint(0, 30)
    hours_offset = random.randint(0, 23)
    minutes_offset = random.randint(0, 59)
    event_time = (datetime.now(timezone.utc) - timedelta(days=days_ago, hours=hours_offset, minutes=minutes_offset))
    
    # Generate event_id (with possibility of duplicates later)
    event_id = random.randint(100000, 999999)
    
    record = {
        "event_id": event_id,
        "device_id": device_id,
        "device_type": device_type,
        "event_time": event_time.isoformat(),
        "event_duration": round(random.uniform(0.1, 5.0), 3),
        "location": {
            "latitude": round(float(fake.latitude()), 6),
            "longitude": round(float(fake.longitude()), 6),
            "city": fake.city(),
            "country": fake.country()
        },
        "metadata": {
            "firmware_version": f"{random.randint(1, 5)}.{random.randint(0, 9)}.{random.randint(0, 99)}",
            "battery_level": random.randint(0, 100),
            "signal_strength": random.randint(-120, 0)
        }
    }
    
    return record, event_id


def introduce_missing_data(record):
    """Introduce missing data randomly"""
    if random.random() < MISSING_DATA_RATE:
        # Randomly remove or nullify fields
        options = [
            lambda r: r.update({"event_duration": None}),
            lambda r: r.update({"device_type": None}),
            lambda r: r["location"].update({"city": None}),
            lambda r: r["location"].update({"latitude": None}),
            lambda r: r["metadata"].update({"battery_level": None}),
            lambda r: r["metadata"].update({"signal_strength": None}),
            lambda r: r.update({"location": None}),  # Entire location missing
            lambda r: r.update({"metadata": None}),  # Entire metadata missing
        ]
        random.choice(options)(record)


def introduce_invalid_values(record):
    """Introduce invalid values"""
    if random.random() < OUTLIER_RATE:
        corruption_type = random.choice([
            "battery_over_100",
            "battery_negative",
            "coordinates_out_of_range",
            "duration_negative",
            "duration_extreme",
            "signal_out_of_range"
        ])
        
        if corruption_type == "battery_over_100":
            if record.get("metadata") is None:
                record["metadata"] = {}
            record["metadata"]["battery_level"] = random.randint(101, 200)
        elif corruption_type == "battery_negative":
            if record.get("metadata") is None:
                record["metadata"] = {}
            record["metadata"]["battery_level"] = random.randint(-50, -1)
        elif corruption_type == "coordinates_out_of_range":
            if record.get("location") is None:
                record["location"] = {}
            record["location"]["latitude"] = random.uniform(91, 180)  # Invalid latitude
            record["location"]["longitude"] = random.uniform(181, 360)  # Invalid longitude
        elif corruption_type == "duration_negative":
            record["event_duration"] = round(random.uniform(-10.0, -0.1), 3)
        elif corruption_type == "duration_extreme":
            record["event_duration"] = round(random.uniform(100.0, 10000.0), 3)
        elif corruption_type == "signal_out_of_range":
            if record.get("metadata") is None:
                record["metadata"] = {}
            record["metadata"]["signal_strength"] = random.randint(1, 100)  # Positive (invalid)


def introduce_outlier(record):
    """Introduce statistical outliers"""
    if random.random() < OUTLIER_RATE:
        # Extreme event_duration (far from normal distribution)
        record["event_duration"] = round(random.uniform(50.0, 500.0), 3)


def make_corrupted_json(record):
    """Create corrupted JSON string"""
    corruption_type = random.choice([
        "missing_quote",
        "missing_bracket",
        "extra_comma",
        "invalid_escape",
        "truncated",
        "unicode_error"
    ])
    
    json_str = json.dumps(record)
    
    if corruption_type == "missing_quote":
        json_str = json_str.replace('"device_id":', 'device_id":', 1)
    elif corruption_type == "missing_bracket":
        json_str = json_str.rsplit("}", 1)[0]  # Remove last }
    elif corruption_type == "extra_comma":
        json_str = json_str.replace('"event_id"', ',"event_id"', 1)
    elif corruption_type == "invalid_escape":
        json_str = json_str.replace('\\"', '\\x"', 1)
    elif corruption_type == "truncated":
        json_str = json_str[:len(json_str)//2]  # Truncate half
    elif corruption_type == "unicode_error":
        json_str = json_str + "\xff\xfe"  # Invalid UTF-8
    
    return json_str


def generate_duplicate(original_record, original_event_id):
    """Generate a duplicate record (same event_id, possibly slightly modified)"""
    duplicate = copy.deepcopy(original_record)
    # Keep same event_id (duplicate)
    duplicate["event_id"] = original_event_id
    # Sometimes duplicate has slightly different timestamp or other field
    if random.random() < 0.5:
        try:
            event_time_str = duplicate["event_time"]
            if event_time_str.endswith("Z"):
                event_time_str = event_time_str.replace("Z", "+00:00")
            event_time = datetime.fromisoformat(event_time_str)
            duplicate["event_time"] = (event_time + timedelta(seconds=random.randint(1, 60))).isoformat()
        except (ValueError, TypeError):
            # If parsing fails, keep original
            pass
    return duplicate


def generate_large_file(file_path, target_size_gb, file_index):
    """Generate a large JSONL file with various data quality issues"""
    target_size_bytes = int(target_size_gb * 1024 * 1024 * 1024)
    current_size = 0
    records_written = 0
    duplicates_added = 0
    corrupted_added = 0
    
    # Track some records for duplicates
    duplicate_pool = []
    
    print(f"Generating file {file_index}: {file_path}")
    print(f"Target size: {target_size_gb:.2f} GB ({target_size_bytes:,} bytes)")
    
    with open(file_path, 'w', encoding='utf-8') as f:
        while current_size < target_size_bytes:
            # Decide what kind of record to generate
            rand = random.random()
            
            if rand < DUPLICATE_RATE and duplicate_pool:
                # Generate duplicate (same event_id)
                original_record, original_event_id = random.choice(duplicate_pool)
                record = generate_duplicate(original_record, original_event_id)
                event_id = original_event_id  # Same event_id for duplicate
                duplicates_added += 1
            else:
                # Generate new record
                record, event_id = generate_valid_record(records_written)
                duplicate_pool.append((copy.deepcopy(record), event_id))
                # Keep pool size manageable (keep last 1000 for duplicates)
                if len(duplicate_pool) > 1000:
                    duplicate_pool.pop(0)
            
            # Introduce data quality issues
            if random.random() < MISSING_DATA_RATE:
                introduce_missing_data(record)
            
            if random.random() < OUTLIER_RATE:
                introduce_outlier(record)
            
            if random.random() < OUTLIER_RATE:
                introduce_invalid_values(record)
            
            # Write record
            if random.random() < CORRUPTION_RATE:
                # Corrupted JSON line
                corrupted_line = make_corrupted_json(record) + "\n"
                f.write(corrupted_line)
                corrupted_added += 1
                current_size += len(corrupted_line.encode('utf-8'))
            else:
                # Valid JSON line
                json_line = json.dumps(record, ensure_ascii=False) + "\n"
                f.write(json_line)
                current_size += len(json_line.encode('utf-8'))
            
            records_written += 1
            
            # Progress update every 100k records
            if records_written % 100000 == 0:
                size_gb = current_size / (1024**3)
                progress = (current_size / target_size_bytes) * 100
                print(f"  Progress: {progress:.1f}% ({size_gb:.2f} GB, {records_written:,} records)")
    
    final_size_gb = os.path.getsize(file_path) / (1024**3)
    print(f"File {file_index} completed:")
    print(f"  Final size: {final_size_gb:.2f} GB")
    print(f"  Records: {records_written:,}")
    print(f"  Duplicates: {duplicates_added:,}")
    print(f"  Corrupted: {corrupted_added:,}")
    print()


def generate_reference_file(file_path, num_records=100):
    """Generate small reference files for broadcast join"""
    print(f"Generating reference file: {file_path}")
    
    file_path_str = str(file_path)
    if "device_info" in file_path_str:
        # Device info reference
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write("device_id,device_name,manufacturer,installation_date\n")
            # Mix popular and rare devices
            all_devices = POPULAR_DEVICES + RARE_DEVICES[:45]
            for i, device_id in enumerate(all_devices[:num_records]):
                f.write(f"{device_id},{fake.word().capitalize()}_Device_{i+1},"
                       f"{fake.company()},{fake.date_between(start_date='-5y', end_date='today')}\n")
    
    elif "firmware_info" in file_path_str:
        # Firmware info reference
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write("firmware_version,release_date,bug_count,is_stable\n")
            for i in range(num_records):
                major = random.randint(1, 5)
                minor = random.randint(0, 9)
                patch = random.randint(0, 99)
                version = f"{major}.{minor}.{patch}"
                f.write(f"{version},{fake.date_between(start_date='-2y', end_date='today')},"
                       f"{random.randint(0, 50)},{random.choice(['true', 'false'])}\n")
    
    file_size_kb = os.path.getsize(file_path) / 1024
    print(f"  Generated {num_records} records, size: {file_size_kb:.2f} KB")
    print()


def main():
    """Main function"""
    print("=" * 60)
    print("Data Generator for Practical Task")
    print("=" * 60)
    print(f"Configuration:")
    print(f"  File size: {FILE_SIZE_GB} GB per file")
    print(f"  Number of large files: {NUM_LARGE_FILES}")
    print(f"  Output directory: {OUTPUT_DIR}")
    print(f"  Corruption rate: {CORRUPTION_RATE * 100:.2f}%")
    print(f"  Missing data rate: {MISSING_DATA_RATE * 100:.2f}%")
    print(f"  Duplicate rate: {DUPLICATE_RATE * 100:.2f}%")
    print(f"  Outlier rate: {OUTLIER_RATE * 100:.2f}%")
    print()
    
    # Create output directory
    output_path = Path(OUTPUT_DIR)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Generate large files
    for i in range(1, NUM_LARGE_FILES + 1):
        file_path = output_path / f"events_large_{i}.jsonl"
        generate_large_file(file_path, FILE_SIZE_GB, i)
    
    # Generate reference files
    print("Generating reference files...")
    device_info_path = output_path / "device_info.csv"
    firmware_info_path = output_path / "firmware_info.csv"
    
    generate_reference_file(device_info_path, num_records=100)
    generate_reference_file(firmware_info_path, num_records=50)
    
    print("=" * 60)
    print("Data generation completed!")
    print(f"Output directory: {output_path.absolute()}")
    print("=" * 60)


if __name__ == "__main__":
    main()

