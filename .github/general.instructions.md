---
applyTo: "**"
---

# General Coding Best Practices

## Code Quality & Maintainability
- Write self-documenting code with clear variable and function names
- Limit function length to 30 lines max, break larger functions into smaller ones
- Follow the Single Responsibility Principle - each function does one thing well
- Use meaningful comments for "why" not "what" (code should explain itself)
- Apply consistent indentation and formatting throughout the codebase
- Avoid nested conditionals deeper than 3 levels - refactor when necessary
- Implement proper error handling with informative error messages
- Avoid magic numbers and strings - use named constants instead

## Performance & Optimization
- Optimize for readability first, then performance if needed
- Avoid premature optimization - measure before optimizing
- Use appropriate data structures for the task (consider time/space complexity)
- Be mindful of memory usage, especially with large datasets
- Implement lazy loading where appropriate for better initial load times
- Consider pagination for large result sets

## Security Practices
- Never trust user input - always validate and sanitize
- Implement proper authentication and authorization
- Use parametrized queries to prevent SQL injection
- Avoid hardcoding sensitive information (keys, passwords)
- Follow the principle of least privilege
- Set appropriate CORS policies
- Implement rate limiting for APIs

## Modern Development Practices
- Use async/await for asynchronous operations instead of callbacks
- Apply functional programming techniques where appropriate
- Write code with testability in mind
- Implement proper logging for monitoring and debugging
- Use environment variables for configuration
- Follow semantic versioning for releases
- Write useful commit messages explaining the "why" of changes

## Project Structure
- Maintain a clear, logical project structure
- Use appropriate design patterns but avoid overengineering
- Separate concerns between layers (presentation, business logic, data access)
- Organize code by feature rather than by technical function when appropriate
- Create reusable, modular components
- Use dependency injection to manage dependencies

## When Generating Code
- Generate code that follows these principles
- Include appropriate error handling
- Add helpful comments for complex logic
- Include examples of usage when generating functions or classes
- Ensure backward compatibility unless explicitly requested otherwise
- Suggest unit tests for critical functionality
- Provide optimization tips for resource-intensive operations
