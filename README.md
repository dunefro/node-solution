# node-solution
this is the solution of the task

1.	Create a Google Cloud Platform (GCP) account (they offer $300 of free credits)
A1. Account created

2.	Containerize the application using Docker
A2. To containerize the application we will create a 
	1. Dockerfile  - to build the images
	2. docker-compose - to check if the application is working or not


Dockefile
```
FROM node:9

# Create app directory
WORKDIR /app

# Install app dependencies
COPY node-hostname/package*.json ./

RUN npm install

# Copying rest of the application to app directory
COPY node-hostname /app

# Expose the port and start the application
Expose 8080

CMD ["npm","start"]
```

I ran docker-compose to check if application is working or not
```
version: "2"  # optional since v1.27.0
services:
  web:
    build: .
    ports:
      - "3000:3000"
```


final output on the browser if we check 
```
{"hostname":"40524c48c829","version":"0.0.1"}
```

We can also use this to build the images
```
DOCKER_BUILDKIT=1 docker image build -t ved-node:v1 .
```


3.	Push the container image to Google Container Registry 
A3. 
	1. Installing gcloud
    ```
	    sudo apt-get install apt-transport-https ca-certificates gnupg
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt-get update && sudo apt-get install google-cloud-sdk
	    gcloud auth login -> went to the browser and then pasted the link over there
	```
    2. Have made the registry public for now, but we can keep it private as well.
	Pushed the image to gcr by the following command 
	```
	docker image push gcr.io/zippy-catwalk-336307/ved-node:v1
    ```

4. Deploying the app in GKE
A4.
	1. Get the access in GKE
	``` Using gcloud 
	gcloud container clusters get-credentials my-first-cluster-1 --zone us-central1-c --project zippy-catwalk-336307
	```
	2. this makes the changes in the config file in .kube. Now our kubeconfig file is pointing to the GKE cluster
	3. Deploying the application
	```
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: node-deployment
      namespace: kube-public
      labels:
        app: node
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: node
      template:
        metadata:
          labels:
            app: node
        spec:
          containers:
          - name: node
            image: gcr.io/zippy-catwalk-336307/ved-node:v1
            ports:
            - containerPort: 3000
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: my-service
      namespace: kube-public
    spec:
      selector:
        app: node
      ports:
        - protocol: TCP
          port: 3000
          targetPort: 3000
    ```
	4. checking if app runs or not
	```
    kubectl get pods -n kube-public 
    NAME                               READY   STATUS    RESTARTS   AGE
    node-deployment-6f4cc5bc7b-2bdj6   1/1     Running   0          2m40s
    node-deployment-6f4cc5bc7b-4fthl   1/1     Running   0          2m40s
    node-deployment-6f4cc5bc7b-lvq47   1/1     Running   0          2m40s
    ```
	5. Check if the svc points correctly to the deployment
	```
    kubectl get ep -n kube-public 
    NAME         ENDPOINTS                                         AGE
    my-service   10.104.0.6:3000,10.104.1.4:3000,10.104.2.6:3000   3m47s
    ```
	6. Making the application externally available
	```
    $kubectl -n kube-public  expose deploy node-deployment --type=LoadBalancer --name=lb-node-service

    $ kubectl get svc -n kube-public
    NAME              TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)          AGE
    lb-node-service   LoadBalancer   10.108.1.195   35.238.158.185   3000:31475/TCP   67s
    my-service        ClusterIP      10.108.7.145   <none>           3000/TCP         7m39s
    ```
	7. Accessing the application via curl
	```
    $ curl 35.238.158.185:3000
    {"hostname":"node-deployment-6f4cc5bc7b-2bdj6","version":"0.0.1"}
    ```
	
	
5.	Expose the application via https (and not http)
A5.
	1. Installing the nginx ingress 
    ```
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.0/deploy/static/provider/cloud/deploy.yaml
    ```
	2. This creates a service which will be helpful for us to externally DNS
    ```
    kubectl get svc -n ingress-nginx
    NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
    ingress-nginx-controller             LoadBalancer   10.108.10.36    34.134.110.124   80:31676/TCP,443:31064/TCP   3m14s
    ingress-nginx-controller-admission   ClusterIP      10.108.10.199   <none>           443/TCP                      3m14s
    ```
	3. Created the ingress
    ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-ingress
      namespace: kube-public
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      rules:
      - host: node.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 3000
    ```
    4. Edited the localhost DNS to point to the loadbalancer
    ```
    $ cat /etc/hosts       
    127.0.0.1	localhost
    127.0.1.1	kali.kali	kali

    # The following lines are desirable for IPv6 capable hosts
    ::1     localhost ip6-localhost ip6-loopback
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
    34.117.61.147 node.example.com
    ```
	5. Now trying from local host
    ```
    $ curl node.example.com
    {"hostname":"node-deployment-6f4cc5bc7b-4fthl","version":"0.0.1"}
    ```
	6. To determine if this is not local pointing
    ```
    curl -v node.example.com
    *   Trying 34.117.61.147:80...
    * Connected to node.example.com (34.117.61.147) port 80 (#0)
    > GET / HTTP/1.1
    > Host: node.example.com
    > User-Agent: curl/7.74.0
    > Accept: */*
    > 
    * Mark bundle as not supporting multiuse
    < HTTP/1.1 200 OK
    < X-Powered-By: Express
    < Content-Type: application/json; charset=utf-8
    < Content-Length: 65
    < ETag: W/"41-7h2q0w3d0ySxTkx6wWRwyamERTE"
    < Date: Sun, 26 Dec 2021 09:15:49 GMT
    < Via: 1.1 google
    < 
    * Connection #0 to host node.example.com left intact
    {"hostname":"node-deployment-6f4cc5bc7b-lvq47","version":"0.0.1"}
    ```
	7. Creating the TLs certificates
    ```
    $ openssl genrsa -des3 -out myCA.key 2048
    Generating RSA private key, 2048 bit long modulus
    ..................+++
    ...................+++
    e is 65537 (0x10001)
    Enter pass phrase for myCA.key:
    Verifying - Enter pass phrase for myCA.key: <"node" -> password here >
    ```
    Certificate here
    ```
    $ openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem
    Enter pass phrase for myCA.key:
    You are about to be asked to enter information that will be incorporated
    into your certificate request.
    What you are about to enter is what is called a Distinguished Name or a DN.
    There are quite a few fields but you can leave some blank
    For some fields there will be a default value,
    If you enter '.', the field will be left blank.
    -----
    Country Name (2 letter code) [AU]:IN
    State or Province Name (full name) [Some-State]:RJ
    Locality Name (eg, city) []:JP
    Organization Name (eg, company) [Internet Widgits Pty Ltd]:vedant
    Organizational Unit Name (eg, section) []:devops
    Common Name (e.g. server FQDN or YOUR name) []:node.example.com
    Email Address []:pareekvedant99@gmail.com
    ```
    8. Creating the k8s secret from these TLS certificate, the key is decrypted before this command.
	```
	kubectl -n kube-public create secret tls my-tls-secret --cert=./certs/tls.crt  --key=./certs/tls.key
	```
	9. Modifying the current ingress
    ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-ingress
      namespace: kube-public
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      tls:
      - hosts:
          - node.example.com
        secretName: my-tls-secret
      rules:
      - host: node.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 3000
    ```
	10. So now if we try with https, it works
    ```
    curl -k https://node.example.com
    {"hostname":"node-deployment-6f4cc5bc7b-4fthl","version":"0.0.1"}
    ```
	10. But if we try with http also it works , so we need a redirection, for this we modify the ingress with default ingress class and forcing tls redirection
    ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-ingress
      namespace: kube-public
      annotations:
        kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/rewrite-target: /
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    spec:
      tls:
      - hosts:
          - node.example.com
        secretName: my-tls-secret
      rules:
      - host: node.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 3000
    ```
	11. This changes the ingress loadbalancer, so we will update the same in out local DNS entry
    ```
    kubectl get ingress -n kube-public
    NAME         CLASS    HOSTS              ADDRESS          PORTS     AGE
    my-ingress   <none>   node.example.com   34.134.110.124   80, 443   38m
    ```
	12. Trying with http and https
	HTTPS
    ```
     curl -k https://node.example.com
    {"hostname":"node-deployment-6f4cc5bc7b-4fthl","version":"0.0.1"}
    ```
    Trying with http
    ```
    curl http://node.example.com  
    <html>
    <head><title>308 Permanent Redirect</title></head>
    <body>
    <center><h1>308 Permanent Redirect</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>
    ```

6. Make a trivial change to the application and do a rolling update (https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
A6. Here we will make a very small change in the code and then will create a v2 tag
```
DOCKER_BUILDKIT=1 docker image build -t gcr.io/zippy-catwalk-336307/ved-node:v2 .
```
Pushing the image
```
docker image push gcr.io/zippy-catwalk-336307/ved-node:v2
```
Rolling update in kubernetes to deploy v2 tag
```
kubectl -n kube-public set image deploy/node-deployment node=gcr.io/zippy-catwalk-336307/ved-node:v2 --record
deployment.apps/node-deployment image updated
```
$ kubectl get pods -n kube-public -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
NAME                               IMAGE
node-deployment-6f8d899d8f-hwfw6   gcr.io/zippy-catwalk-336307/ved-node:v2
node-deployment-6f8d899d8f-qp8dq   gcr.io/zippy-catwalk-336307/ved-node:v2
node-deployment-6f8d899d8f-x7z9r   gcr.io/zippy-catwalk-336307/ved-node:v2
```

7. Helm-ify the deployment (https://helm.sh)
A7. for this we can do helm create node-example
	1. We added pre-hook for tls secret for ingress to use
    2. To run the chart
    ```
    helm install node charts/node-example
    ```
    3. After this you will get an ingress entry, point it to localhost
    4. with the help of HPA we can solve the problem of scaling and downtime



Production Quality
1. public DNS
2. Make the image secure
3. Create a pipeline for auto-deployment on a tagged release.

	
