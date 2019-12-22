# RedisGears Write-Behind Recipe

## System requirements

* Redis v5.0.7 or above,
* Relational database: MySQL (any version will do) or Oracle (tested with 11g and 12c) database,
* Redis Enterprise Software v5.4.11-2 and above,
* RedisGears module build for Ubuntu Bionic

## Configuration

TBD: key names and tables

## Installing with OSS Redis

* Install [Docker](#insalling_docker) and git.
* Clone the RedisGears repo: `git clone github.com/RedisGears/RedisGears.git`
* Run:
  ```
docker run --name gears -d redisgears:latest
docker run --name mysql -d mysql:latest
  ```
TBD

## Installing on Redis Enterprise Software cluster

* Create a Redis cluster.
* Install RedisGears dependencies on all nodes.
* Install RedisGears module.
* Download and extract the RedisGears Write-Behind Recipe archive into `/opt/gears-wb` on one of the nodes, which we'll refer to as the "Controlling node".

Depending on your favorite database, continue with either **Running with MySQL** or **Running with Oracle**.

### Running with MySQL

#### Install and configure MySQL

* Run `/opt/gears-wb/mysql/install-mysql-docker`. This will run an MySQL database in a container.
** Alternatively, run `/opt/gears-wb/mysql/install-mysql` to install MySQL directly on host.

* On the controlling node, install Oracle client with `/opt/gears-wb/mysql/install-mysql-client`.

* Add the following to `/etc/hosts`:

  ```
  127.0.0.1 mysql
  ```

* Create a database with `/opt/gears-wb/mysql/rs/create-db`.

* It's now possible connect to the database using `mysql test/passwd@/localhost` and check that the tables were created:

  ```
  select * from person1;
  select * from car;
  ```

#### Configure cluster nodes

* For each node, add the following to its `/etc/hosts` file, where `MYSQL-IP` is the controlling node IP:

  ```
  MYSQL-IP mysql
  ```

* Install MySQL client with `/opt/gears-wb/mysql/install-mysql-client`.
* Install Oracle python client with `/opt/gears-wb/mysql/install-mysql-python-client`.

#### Run the Gear

* Run `/opt/gears-wb/mysql/start-gear`.
* From within `redis-cli`, `RG.DUMPREGISTRATIONS` will return a list of registrations.

### Running with Oracle

#### Install and configure Oracle

* [Install Docker](#insalling_docker) on either one of the Redis cluster nodes or on a dedicated host.

* Run `/opt/gears-wb/oracle/install-oracle-docker`. This will run an Oracle database in a container.

* On the controlling node, install Oracle client with `/opt/gears-wb/oracle/install-oracle-client`.

* Add the following to `/etc/hosts`:

  ```
  127.0.0.1 oracle
  ```

* Create a database with `/opt/gears-wb/oracle/rs/create-db`.

* It's now possible connect to the database using `rlwrap sqlplus test/passwd@//localhost/xe` and check that the tables were created:

  ```
  select * from person1;
  select * from car;
  ```

#### Configure cluster nodes

* For each node, add the following to its `/etc/hosts` file, where `ORACLE-IP` is the controlling node IP:

  ```
  ORACLE-IP oracle
  ```

* Install Oracle client with `/opt/gears-wb/oracle/install-oracle-client`.
* Install Oracle python client with `/opt/gears-wb/oracle/install-oracle-python-client`.

#### Run the write-behind gear

* Run `/opt/gears-wb/oracle/start-gear`.
* From within `redis-cli`, `RG.DUMPREGISTRATIONS` will return a list of registrations.

## Installing on RHEL-Docker

### Install and configure MySQL

### Install and configure Oracle

## Testing

* From the controlling node, run `/opt/gears-wb/test/test_write_behind.py`.

## Diagnostics

TBD

## Appendix

### Installing Docker {#installing_docker}
Run the following:
```
bash <(curl -fsSL https://get.docker.com)
systemctl enable docker
```

Verify with ```docker version```.
