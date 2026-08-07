ALTER TABLE IF EXISTS test.notifications
    DETACH PARTITION test.test__notifications__2024_12;

ALTER TABLE IF EXISTS test.notifications
    DETACH PARTITION test.notifications_2025_01;
