# FlyBase Specific Chado Functions

## Description

This repository contains FlyBase specific functions for the FlyBase Chado database schema.
All functions are stored in the **flybase** schema in whatever database you specify.

## Documentaiton

* [Full docs](https://flybase.github.io/docs/chado/functions)

## Install

The following will install the flybase schema with all functions into `mydb`.

Change this to whatever your local database name is.

```bash
> psql -f apply-flybase-schema.sql mydb
```

Additional connection parameters (host, user, password, port, etc.) may be required.  See the 
PostgreSQL docs for the psql client for more information.

