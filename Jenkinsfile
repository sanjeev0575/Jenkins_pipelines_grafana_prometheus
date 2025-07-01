pipeline {
    agent any
    
    environment {
        DOCKER_HUB_REPO = 'kastrov/techsolutions-app'
        K8S_CLUSTER_NAME = 'kastro-cluster'
        AWS_REGION = 'us-east-1'
        NAMESPACE = 'default'
        APP_NAME = 'techsolutions'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    def buildNumber = env.BUILD_NUMBER
                    def imageTag = "${DOCKER_HUB_REPO}:${buildNumber}"
                    def latestTag = "${DOCKER_HUB_REPO}:latest"
                    
                    // Build the Docker image
                    sh "docker build -t ${imageTag} ."
                    sh "docker tag ${imageTag} ${latestTag}"
                    
                    env.IMAGE_TAG = buildNumber
                }
            }
        }
        
        stage('Push to DockerHub') {
            steps {
                echo 'Pushing Docker image to DockerHub...'
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                        sh "echo \${DOCKER_PASSWORD} | docker login -u \${DOCKER_USERNAME} --password-stdin"
                        sh "docker push ${DOCKER_HUB_REPO}:${env.IMAGE_TAG}"
                        sh "docker push ${DOCKER_HUB_REPO}:latest"
                    }
                }
            }
        }
        
        stage('Configure AWS and Kubectl') {
            steps {
                echo 'Configuring AWS CLI and kubectl...'
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        sh "aws configure set region ${AWS_REGION}"
                        sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${K8S_CLUSTER_NAME}"
                        sh "kubectl config current-context"
                        sh "kubectl get nodes"
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying application to Kubernetes...'
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        // Update the deployment image
                        sh "sed -i 's|kastrov/techsolutions-app:latest|kastrov/techsolutions-app:${env.IMAGE_TAG}|g' k8s/deployment.yaml"
                        
                        // Apply Kubernetes manifests
                        sh "kubectl apply -f k8s/deployment.yaml"
                        
                        // Wait for deployment to be ready
                        sh "kubectl rollout status deployment/${APP_NAME}-deployment --timeout=300s"
                        
                        // Verify deployment
                        sh "kubectl get pods -l app=${APP_NAME}"
                        sh "kubectl get svc ${APP_NAME}-service"
                    }
                }
            }
        }
        
        stage('Install Nginx Ingress Controller') {
            steps {
                echo 'Installing Nginx Ingress Controller...'
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        // Check if ingress controller is already installed
                        def ingressExists = sh(
                            script: "kubectl get namespace ingress-nginx",
                            returnStatus: true
                        )
                        
                        if (ingressExists != 0) {
                            echo 'Installing Nginx Ingress Controller...'
                            sh "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml"
                            
                            // Wait for ingress controller to be ready
                            sh "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s"
                        } else {
                            echo 'Nginx Ingress Controller already exists'
                        }
                    }
                }
            }
        }
        
        stage('Deploy Ingress') {
            steps {
                echo 'Deploying Ingress resource...'
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        // Apply ingress configuration
                        sh "kubectl apply -f k8s/ingress.yaml"
                        
                        // Wait a moment for ingress to be created
                        sleep(10)
                        
                        // Get ingress details
                        sh "kubectl get ingress ${APP_NAME}-ingress"
                        sh "kubectl describe ingress ${APP_NAME}-ingress"
                    }
                }
            }
        }
        
        stage('Get Ingress URL') {
            steps {
                echo 'Getting Ingress URL...'
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        // Wait for external IP to be assigned
                        timeout(time: 10, unit: 'MINUTES') {
                            waitUntil {
                                script {
                                    def result = sh(
                                        script: "kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                                        returnStdout: true
                                    ).trim()
                                    
                                    if (result && result != '') {
                                        env.INGRESS_URL = "http://${result}"
                                        echo "Ingress URL: ${env.INGRESS_URL}"
                                        return true
                                    }
                                    return false
                                }
                            }
                        }
                        
                        // Display all access information
                        echo "========================================="
                        echo "DEPLOYMENT SUCCESSFUL!"
                        echo "========================================="
                        echo "Application URL: ${env.INGRESS_URL}"
                        echo ""
                        echo "Available Paths:"
                        echo "- Home Page: ${env.INGRESS_URL}/"
                        echo "- About Page: ${env.INGRESS_URL}/about"
                        echo "- Services Page: ${env.INGRESS_URL}/services"
                        echo "- Contact Page: ${env.INGRESS_URL}/contact"
                        echo "========================================="
                        
                        // Test the endpoints
                        sh "curl -I ${env.INGRESS_URL}/ || echo 'Home page check failed'"
                        sh "curl -I ${env.INGRESS_URL}/about || echo 'About page check failed'"
                        sh "curl -I ${env.INGRESS_URL}/services || echo 'Services page check failed'"
                        sh "curl -I ${env.INGRESS_URL}/contact || echo 'Contact page check failed'"
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up Docker images...'
            sh "docker rmi ${DOCKER_HUB_REPO}:${env.IMAGE_TAG} || true"
            sh "docker rmi ${DOCKER_HUB_REPO}:latest || true"
        }
        
        success {
            echo 'Pipeline completed successfully!'
            echo "Access your application at: ${env.INGRESS_URL}"
        }
        
        failure {
            echo 'Pipeline failed! Please check the logs.'
        }
    }
}