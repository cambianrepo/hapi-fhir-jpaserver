
## Configuration
Changes have been made to the application.yml for:
 * use Postgres as the database
 * use Flyway to provision the database schema
 * enable partitioning based on URL (multi-tenant)

__NOTE__:  The database password should be changed for production by using environment variable.

## Local testing
Start Postgres in Docker (first ensure docker is running on your PC)
```bash
docker compose -f docker-compose-postgres.yml up hapi-fhir-postgres
```

Use maven command to start local JVM process
```bash
mvn spring-boot:run
```
Also see [Spring Boot section in HAPI README.md](./README.md#using-spring-boot)


## Build a deployable package for Docker

To build the docker image, run
```bash
docker build -t hapi-fhir/hapi-fhir-jpaserver-cambian .
```

To test the docker image in local docker, run
```bash
docker run -p 8080:8080 hapi-fhir/hapi-fhir-jpaserver-cambian:latest
 -or-
docker compose -f docker-compose-postgres.yml up hapi-fhir-postgres

```
The image can then be copied to AWS ECS (Elastic Container Server), talk to devops about this.

Also see [Docker section in HAPI README.md](./README.md#using-the-dockerfile-and-multistage-build)


## Deploy to AWS ECS

1. Retrieve an authentication token and authenticate your Docker client to your registry. Use the AWS TOOLS 
  * for __PowerShell__:
    ```
    (Get-ECRLoginCommand).Password | docker login --username AWS --password-stdin 975050054044.dkr.ecr.ca-central-1.amazonaws.com
    ```
      Note: If you receive an error using the AWS TOOLS for PowerShell, make sure that you have the latest version of the AWS TOOLS for PowerShell and Docker installed.

  * Or, for a __bash shell__:
    ``` 
    aws ecr get-login-password --profile cambian-dev | docker login --username AWS --password-stdin 975050054044.dkr.ecr.ca-central-1.amazonaws.com  
    ```
    (see https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecr/get-login-password.html)

2. Build your Docker image if not already built
    ```
    docker build -t cambian-devhapi-fhir .
    ```
3. After the build completes, tag your image so you can push the image to this repository:
    ```
      not working, old ==> docker tag cambian-devhapi-fhir:latest 975050054044.dkr.ecr.ca-central-1.amazonaws.com/cambian-devhapi-fhir:latest
      -or-
    docker tag hapi-fhir/hapi-fhir-jpaserver-cambian:latest 975050054044.dkr.ecr.ca-central-1.amazonaws.com/cambian-devhapi-fhir:v20250526
    ```
4. Run the following command to push this image to your newly created AWS repository:
    ``` 
    docker push 975050054044.dkr.ecr.ca-central-1.amazonaws.com/cambian-devhapi-fhir:latest
      -or-
    docker push 975050054044.dkr.ecr.ca-central-1.amazonaws.com/cambian-devhapi-fhir:v20250526
    
    ```
The image must be built for x86:sunrise:
After you finish uploading, just let me know with the list of environment variables!

