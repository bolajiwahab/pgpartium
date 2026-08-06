ALTER TABLE test.notifications
    DETACH PARTITION test.test__notifications__2024_12 CONCURRENTLY;

DROP TABLE test.test__notifications__2024_12;

ALTER TABLE test.notifications
    DETACH PARTITION test.notifications_2025_01 CONCURRENTLY;

DROP TABLE test.notifications_2025_01;
