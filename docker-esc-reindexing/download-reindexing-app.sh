NEXUS_USER=user
NEXUS_PASS=pass

curl --user $NEXUS_USER:$NEXUS_PASS https://nexus.alfresco.com/nexus/service/local/repositories/enterprise-releases/content/org/alfresco/alfresco-elasticsearch-reindexing/4.0.0/alfresco-elasticsearch-reindexing-4.0.0-app.jar -o alfresco-elasticsearch-reindexing-4.0.0-app.jar
