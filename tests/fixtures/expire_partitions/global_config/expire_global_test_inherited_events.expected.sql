ALTER TABLE IF EXISTS test.inherited_events
    DETACH PARTITION test.inherited_events_2024_12 CONCURRENTLY;

DROP TABLE IF EXISTS test.inherited_events_2024_12;
