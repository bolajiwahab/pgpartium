Given your tooling scope, I would probably document this explicitly:

Partition detach operations are generated as declarative DDL and are not guaranteed idempotent due to PostgreSQL limitations.

That is honest and operationally sane.


One thing you could do is document detach semantics explicitly:

PostgreSQL does not support DETACH PARTITION IF EXISTS.
Generated detach statements are therefore only partially idempotent.
A migration may fail if the partition has already been detached externally.

“We prefer named intent over inline computation”
