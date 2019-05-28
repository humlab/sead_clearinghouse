
## A new transfer approach instead of instead of triggers

## Approach and Postulates

* The system outputs DML and data files that can be added to the change managemnt system.
* Generate CSV text files for each table where all PK and FK's have been resolved

    > copy public.tbl_abundance_elements to '/tmp/tbl_abundance_elements.sql';

* Generate COPY FROM statements for each table
* Relay on UPSERTS server side
* All constraint are checked at commit (not before)

## Obstacles

    * SEAD ids need to be reserved in advance. This will create gaps ins equences if roll backed.
    * All local PK's (without glocal PK) must be assigned a reserved ID for each sequence
    * Need ways of identifying foreign keys columns, the PK they reference, and assigning the global, previously reserved PK
    * COPY TO doesn't do UPSERT, so we need trigger tables anyhow

## Process

```
    For each table T (filtered by submission):

       1. Find number N of new records { P } i.e. records having public_id = 0

       2. Reserve and assign PK id:s for new records
          1. Sync sequence using setval current max(ID)
          2. Reserve range (currval, currval + N - 1) using setval('sq', currval() + N)
          3. Assign ID:s in range to each new records (to a new field? or to "public_db_id"? as negative number in "public_db_id"?)

       1.4. For each table F having a FK-column that references T
            1.4.1. Update ID for each FK-column that references a record in { P }

    For each table T:

        1. COPY rows in T to text-file "T.DML"
        2. Generate "COPY FROM" statement that reads "T.DML" and inserts data to "tbl_trigger_transport"

    Package data-files and COPY statements into a CS-deploy script
```

Questions

     Assign UUID as well?

TODO:

    1. Create script that initializes the transport schema
        1. Create schema
        2. Create script that generates transport gateway tables based on current public schema
        3. Create scripts that generates and assign instead of triggers for each tables that make an UPSERT into target public tables

