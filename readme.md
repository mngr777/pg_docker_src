# Usage

* Clone repository
```
$ git clone https://github.com/mngr777/pg_docker_src.git
$ cd ./pg_docker_src
```

* Get GEOS, PostgreSQL and PostGIS source files (from github or other source)
```
$ git clone https://github.com/libgeos/geos.git
$ git clone https://github.com/postgres/postgres.git
$ git clone https://github.com/postgis/postgis.git
```

* Modify source files

* Build and start Docker image
```
$ docker-compose build
$ docker-compose up
```
