---
applyTo: "**/*.ts,**/*.tsx"
---
# TypeScript & React Best Practices

Apply the [general coding guidelines](./general-coding.instructions.md) to all code.

## TypeScript Guidelines
- Use strict TypeScript configuration with `strict: true`
- Define explicit types for function parameters and return values
- Use interfaces for objects that represent entities, types for simpler constructs
- Leverage TypeScript utility types (Pick, Omit, Partial, Required, etc.)
- Avoid using `any` - use `unknown` with type guards when type is uncertain
- Define readonly properties for immutable data
- Use discriminated unions for handling state with different shapes
- Create generic components and functions when appropriate
- Define proper typing for API responses and requests
- Use enums for fixed sets of related values
- Properly handle nullable types with optional chaining (?.) and nullish coalescing (??)
- Add JSDoc comments for complex types and non-obvious behavior

## React Fundamentals
- Use functional components with hooks instead of class components
- Apply proper dependency arrays in useEffect and useMemo hooks
- Extract business logic to custom hooks for reusability
- Memoize expensive calculations with useMemo
- Prevent unnecessary re-renders with React.memo for pure components
- Use useCallback for functions passed to child components
- Implement controlled components for form inputs
- Pass only required props to components (avoid prop drilling)
- Avoid direct DOM manipulation - use refs when necessary
- Keep components small and focused on a single responsibility

## React State Management
- Use useState for simple component-level state
- Implement useReducer for complex state logic
- Apply useContext for sharing state across component trees
- Consider global state management only when necessary (Redux, Zustand, Jotai)
- Keep state as close as possible to where it's used
- Separate UI state from application state
- Minimize state duplication and ensure single source of truth
- Normalize complex state structures for better performance

## Component Design
- Create atomic, reusable components
- Implement proper prop validation with TypeScript
- Use composition over inheritance
- Design components with accessibility in mind
- Support keyboard navigation for interactive elements
- Implement theming using CSS variables or styled-components
- Follow responsive design principles
- Use CSS modules or styled-components for component styling
- Implement lazy loading for larger components with React.lazy

## React Performance Optimization
- Virtualize long lists with react-window or react-virtualized
- Implement code splitting with dynamic imports
- Use proper keys for list items (avoid using index as key)
- Avoid inline function definitions in render
- Properly handle cleanup in useEffect to prevent memory leaks
- Use debouncing/throttling for frequently firing events
- Implement memoization judiciously

## Testing in React & TypeScript
- Write unit tests for components using React Testing Library
- Test for accessibility with axe-core or similar tools
- Use TypeScript to ensure prop types are correct
- Test custom hooks with renderHook
- Implement integration tests for complex workflows
- Mock external dependencies in tests
- Use snapshot testing sparingly

## React & API Integration
- Implement proper loading and error states
- Use React Query or SWR for data fetching and caching
- Handle optimistic updates for better UX
- Properly type API responses with TypeScript interfaces
- Implement retry logic for failed requests
- Add cancellation for abandoned requests
