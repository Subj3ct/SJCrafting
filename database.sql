-- SJCrafting Database Schema
-- Run this SQL file if you have issues with automatic database creation

-- Player crafting data table (stores player levels and XP)
CREATE TABLE IF NOT EXISTS `player_crafting` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) UNIQUE NOT NULL,
    `level` INT DEFAULT 1,
    `xp` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_level` (`level`)
);

-- Admin-placed crafting benches table
CREATE TABLE IF NOT EXISTS `admin_crafting_benches` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `bench_type` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `coords` TEXT NOT NULL,
    `allowed_jobs` TEXT,
    `placed_by` VARCHAR(50) NOT NULL,
    `custom_prop` VARCHAR(100),
    `weapon_repair` BOOLEAN DEFAULT FALSE,
    `placed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `is_active` BOOLEAN DEFAULT TRUE,
    
    INDEX `idx_type` (`bench_type`),
    INDEX `idx_active` (`is_active`),
    INDEX `idx_placed_by` (`placed_by`)
);

-- Player-placed crafting benches table
CREATE TABLE IF NOT EXISTS `player_crafting_benches` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `bench_type` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `coords` TEXT NOT NULL,
    `allowed_jobs` TEXT,
    `placed_by` VARCHAR(50) NOT NULL,
    `placed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `is_active` BOOLEAN DEFAULT TRUE,
    
    INDEX `idx_type` (`bench_type`),
    INDEX `idx_active` (`is_active`),
    INDEX `idx_placed_by` (`placed_by`)
);

-- Optional: Add some sample data for testing
-- INSERT INTO `player_crafting` (`citizenid`, `level`, `xp`) VALUES ('test_citizen_123', 1, 0);
-- INSERT INTO `admin_crafting_benches` (`bench_type`, `label`, `coords`, `placed_by`, `weapon_repair`) 
-- VALUES ('weapon_bench', 'Weapon Crafting Bench', '{"x": 123.45, "y": 678.90, "z": 12.34}', 'admin', TRUE); 