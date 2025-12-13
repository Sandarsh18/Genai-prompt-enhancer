# Contributing to GenAI Prompt Enhancer

First off, thank you for considering contributing to GenAI Prompt Enhancer! 🎉

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed and what behavior you expected**
* **Include logs, screenshots, or animated GIFs**
* **Include your environment details** (OS, Kubernetes version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a detailed description of the suggested enhancement**
* **Explain why this enhancement would be useful**
* **List examples of how it would work**

### Pull Requests

1. Fork the repo and create your branch from `master`
2. If you've added code that should be tested, add tests
3. Ensure the test suite passes
4. Make sure your code follows the existing style
5. Write a clear commit message
6. Update documentation if needed

## 🎯 Development Process

### Setting Up Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/genai-prompt-enhancer.git
cd genai-prompt-enhancer

# Add upstream remote
git remote add upstream https://github.com/Sandarsh18/genai-prompt-enhancer.git

# Create a branch
git checkout -b feature/your-feature-name
```

### Running Tests

```bash
# Run all tests
./test-all.sh

# Run specific service tests
cd rewrite-service && pytest
cd summarize-service && pytest
cd email-service && pytest
```

### Code Style

* **Python**: Follow PEP 8 guidelines
* **JavaScript/React**: Follow Airbnb style guide
* **Use meaningful variable and function names**
* **Add comments for complex logic**
* **Keep functions small and focused**

### Commit Messages

Follow conventional commits format:

```
feat: add new summarization algorithm
fix: resolve memory leak in rewrite service
docs: update Kubernetes deployment guide
refactor: simplify NGINX configuration
test: add integration tests for email service
```

## 🏗️ Architecture Guidelines

### Adding a New Microservice

1. Create service directory with Dockerfile and requirements.txt
2. Add Kubernetes manifests in `k8s/` directory
3. Configure service in NGINX gateway
4. Add HPA configuration if needed
5. Update README and documentation

### Modifying Kubernetes Resources

* Test changes in Minikube first
* Ensure resource limits are appropriate
* Add readiness and liveness probes
* Consider auto-scaling implications

## 📝 Documentation

* Update README.md for user-facing changes
* Add inline code comments for complex logic
* Update API documentation for endpoint changes
* Include examples for new features

## 🧪 Testing Requirements

* Write unit tests for new functions
* Add integration tests for API endpoints
* Test Kubernetes deployments locally
* Verify auto-scaling behavior
* Check monitoring metrics

## 🎨 Design Principles

* **Cloud-Native**: Design for Kubernetes from the start
* **Microservices**: Keep services independent and loosely coupled
* **Observability**: Add metrics, logs, and traces
* **Resilience**: Handle failures gracefully
* **Performance**: Consider scaling and resource usage

## 📋 Checklist Before Submitting

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## 🚀 After Your PR is Merged

* Delete your feature branch
* Update your local master branch
* Consider contributing more! 🎉

## 💬 Community

* Join discussions in GitHub Issues
* Help others with their questions
* Share your use cases and experiences

## 📜 Code of Conduct

* Be respectful and inclusive
* Welcome newcomers
* Provide constructive feedback
* Focus on what is best for the community

Thank you for contributing! 🙏
