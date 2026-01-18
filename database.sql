-- VPS Blocker Connection Logs Table
-- Run this SQL in your database to create the table

CREATE TABLE IF NOT EXISTS `vps_blocker_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifiers` TEXT NOT NULL,
    `ip` VARCHAR(50) NOT NULL,
    `is_proxy` TINYINT(1) NOT NULL DEFAULT 0,
    `timestamp` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `ip_index` (`ip`),
    KEY `timestamp_index` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
