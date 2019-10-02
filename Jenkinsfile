pipeline {
    agent none
    stages {
        stage('Lint') {
            agent { dockerfile true }
            steps {
                sh 'bundle exec rubocop'
            }
        }
        stage('Test'){
            agent { dockerfile true }
            steps {
                sh 'bundle exec rspec spec/**/*_spec.rb'
            }
        }
        stage('Docker Build') {
            agent any
            /*when { branch 'master' }*/
            steps {
                echo 'I would do a docker build.'
                sh 'docker build -f docker/Dockerfile -t dtr-tst.internal.yale.edu:latest .'
                sh 'docker push dtr-tst.internal.yale.edu:latest'
            }
        }
    }
}
