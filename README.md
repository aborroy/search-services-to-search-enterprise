# Step by step guide to migrate from Search Services to Search Enterprise

From ACS Enterprise 7.1 two Search Engines are available:

* [Search Services 1.x and 2.x](https://docs.alfresco.com/search-services/latest/), that is relaying on a customization of [Apache SOLR 6.6](https://solr.apache.org/guide/6_6/)
* [Search Enterprise 3.x and 4.x](https://docs.alfresco.com/search-enterprise/latest/), that is a standard client for [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/7.10/index.html) and [OpenSearch](https://opensearch.org/docs/1.3/)

This project provides a step by step tutorial to upgrade an existing ACS running with Search Services (Solr) to a new ACS running with Search Enterprise (OpenSearch). Note that deploying the product in *production* environments would require additional configuration.

Docker Images from [quay.io](https://quay.io/organization/alfresco) are used, since this product is only available for Alfresco Enterprise customers. In addition, [Alfresco Nexus](https://nexus.alfresco.com) credentials are required. If you are Enterprise Customer or Partner but you are still experimenting problems to download Docker Images or download artifacts from Nexus, contact [Alfresco Hyland Support](https://community.hyland.com) in order to get required credentials and permissions.

This project provides different sample projects to support this configuration:

* [docker-solr](docker-solr) folder contains Docker Compose template to deploy ACS Enterprise 23.1 using Search Services (Solr)
* [docker-esc](docker-esc) folder contains Docker Compose template to deploy ACS Enterprise 23.1 using Search Enterprise (OpenSearch). Configuration to use Search Enterprise with Elasticsearch can be also supported with minor modifications
* [alfresco-go-cli-scripts](alfresco-go-cli-scripts) folder contains a shell script to create documents in ACS for custom content models
* [models](models) folder contains sample Alfresco content models
* [docker-esc-reindexing](docker-esc-reindexing) folder contains local resources to run Alfresco Reindexing App for Search Enterprise (OpenSearch)

Running this tutorial involves following steps:

1. Prepare the *source* ACS 23.1 deployment with Search Services (Solr)
2. Prepare the Reindexing App for Search Enterprise (OpenSearch)
3. Prepare the *target* ACS 23.1 deployment with Search Enterprise (OpenSearch)
4. Run the Reindexing App for Search Enterprise (OpenSearch)


## 1. Prepare source ACS 23.1

Run [docker-solr](docker-solr) template

```sh
cd docker-solr
docker compose up
```

**Custom content models**

Upload [models/data-dictionary/custom-content-model.xml](models/data-dictionary/custom-content-model.xml) to `Repository > Data Dictionary > Models` folder to deploy `cfp` content model. Be sure that `Model Active` property is enabled

Import Model [models/model-manager/conference-model.zip](models/model-manager/conference-model.zip) to **Model Manager** in Share web application to deploy `conference` model. Be sure that `Activate` action is enabled

Note that [acme-model](models/addon/acme-model) is deployed in the Repository as an addon in [acme-model-1.0.0.jar](docker-solr/alfresco/modules/jars)

**Create sample content**

Use sample Alfresco Go CLI Script provided in [alfresco-go-cli-scripts](alfresco-go-cli-scripts) to create sample content from custom content models

```sh
cd alfresco-go-cli-scripts
```

Download `alfresco` Go CLI binary from https://github.com/aborroy/alfresco-go-cli/releases

Create default endpoint and credentials for Alfresco Repository

```sh
./alfresco config set -s http://localhost:8080/alfresco -u admin -p admin
```

Run the script to upload files to Alfresco Repository

```sh
./create-custom-content.sh
```

This will create the following files in `Shared/folder` folder: file_acme.txt, file_cfp.txt, file_conf.txt

>> From this point source ACS Repository contains document from custom content models

**Download Namespace to Prefix Mapping**

Note that the addon [model-ns-prefix-mapping](https://github.com/AlfrescoLabs/model-ns-prefix-mapping) is deployed in the repository as an addon in [model-ns-prefix-mapping-1.0.0.jar](docker-solr/alfresco/modules/jars)

Save JSON mapping to a local file

```sh
curl --user admin:admin http://localhost:8080/alfresco/s/model/ns-prefix-map -o reindex.prefixes-file.json
```

>> This file will be used by the Reindexing App later.


## 2. Prepare Reindexing App

Download Reindexing App from [Alfresco Nexus](https://nexus.alfresco.com)

```sh
cd docker-esc-reindexing
curl --user $NEXUS_USER:$NEXUS_PASS \
https://nexus.alfresco.com/nexus/service/local/repositories/enterprise-releases/content/org/alfresco/alfresco-elasticsearch-reindexing/4.0.0/alfresco-elasticsearch-reindexing-4.0.0-app.jar \
-o alfresco-elasticsearch-reindexing-4.0.0-app.jar
```

Move `reindex.prefixes-file.json` file to this folder

```sh
move ../alfresco-go-cli-scripts/reindex.prefixes-file.json .
```

## 3. Prepare target ACS 23.1

Template [docker-esc](docker-esc) includes ACS 23.1 with Search Enterprise (OpenSearch) and exposes all the services required by Reindexing App:

* ActiveMQ: tcp://localhost:61616
* Database: jdbc:postgresql://localhost:5432/alfresco
* Transform Service: http://localhost:8095/transform/config
* OpenSearch: http://localhost:9200

```sh
cd docker-esc
```

**Replicate Database**

A Replica of Alfresco Database is required. For this tutorial, existing PostgreSQL data from *source* Database is copied to *target* deployment.

```sh
mkdir data
cd data
cp -r ../../docker-solr/data/postgres-data .
```

**Reuse Content Store**

For this tutorial, existing Content Store from *source* is mounted as external volume in [compose.yaml](docker-esc/compose.yaml)

```yaml
  alfresco:
    volumes: 
        - ../docker-solr/data/alf-repo-data:/usr/local/tomcat/alf_data
```

**Deploy custom models**

Both `cfp` and `conference` content models are already available, since database and content store from *source* ACS is re-used

In addition, [acme-model](models/addon/acme-model) is deployed in the Repository as an addon in [acme-model-1.0.0.jar](docker-esc/alfresco/modules/jars)

**Create Index in OpenSearch**

Run [docker-esc](docker-esc) template

```sh
docker compose up
```

Once the deployment is up & ready log in Alfresco Workspace using default credentials (admin/admin) and click "Search"

http://localhost:8080/workspace/

Verify the model has been created in OpenSearch using the following URL:

http://localhost:9200/alfresco/_mapping

```json
{"alfresco":
	{"mappings":
		{"dynamic":"false","properties":
			{"ALIVE":{"type":"boolean"},"ANAME":{"type":"keyword"},"...": {"...":"..."} }
		}
	}
}
```

## 4. Run Reindexing App

At this point, Reindeing App can be run to populate OpenSearch index in *target* ACS

```sh
cd docker-esc-reindexing
java -jar alfresco-elasticsearch-reindexing-4.0.0-app.jar \
  --alfresco.reindex.jobName=reindexByIds \
  --alfresco.reindex.pagesize=100 \
  --alfresco.reindex.batchSize=100  \
  --alfresco.reindex.fromId=1 \
  --alfresco.reindex.toId=896 \
  --alfresco.reindex.concurrentProcessors=2 \
  --alfresco.accepted-content-media-types-cache.base-url=http://localhost:8095/transform/config \
  --spring.activemq.broker-url="tcp://localhost:61616?jms.useAsyncSend=true" \
  --spring.elasticsearch.rest.uris=http://localhost:9200 \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/alfresco \
  --alfresco.reindex.prefixes-file=file:reindex.prefixes-file.json

Step: [reindexByIdsStep] executed in 2s185ms
Total number of indexed nodes (includes retried items) 786
Total number of failed nodes (includes retried items) 0
Total number of updated nodes with Path (includes retried items) 785
Total number of nodes with failed Path update (includes retried items) 0  
``` 