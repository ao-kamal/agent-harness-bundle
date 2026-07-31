# Example: Building a Contact Form Component

This example demonstrates generating a complete form component with validation, accessibility, and tests.

---

## Scenario

**Goal**: Create a `ContactForm` component with:

- Name, email, and message fields
- Client-side validation
- Loading and error states
- Full accessibility
- Comprehensive tests

---

## Step 1: Generate Types

```typescript
// src/components/ContactForm/types.ts
import type { FormHTMLAttributes } from "react";

/**
 * Contact form submission data
 */
export interface ContactFormData {
  name: string;
  email: string;
  message: string;
}

/**
 * Contact form field errors
 */
export interface ContactFormErrors {
  name?: string;
  email?: string;
  message?: string;
}

/**
 * Props for the ContactForm component
 */
export interface ContactFormProps extends Omit<FormHTMLAttributes<HTMLFormElement>, "onSubmit"> {
  /**
   * Called when form is submitted with valid data
   */
  onSubmit: (data: ContactFormData) => Promise<void>;

  /**
   * Initial form values
   */
  defaultValues?: Partial<ContactFormData>;

  /**
   * Whether the form is in a submitting state
   */
  loading?: boolean;

  /**
   * Server error message to display
   */
  serverError?: string;
}
```

---

## Step 2: Generate Component

```tsx
// src/components/ContactForm/ContactForm.tsx
import { forwardRef, useId, useState, type FormEvent } from "react";
import { cn } from "@/lib/utils";
import type { ContactFormProps, ContactFormData, ContactFormErrors } from "./types";

const validateEmail = (email: string): boolean => {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

const validate = (data: ContactFormData): ContactFormErrors => {
  const errors: ContactFormErrors = {};

  if (!data.name.trim()) {
    errors.name = "Name is required";
  } else if (data.name.length < 2) {
    errors.name = "Name must be at least 2 characters";
  }

  if (!data.email.trim()) {
    errors.email = "Email is required";
  } else if (!validateEmail(data.email)) {
    errors.email = "Please enter a valid email address";
  }

  if (!data.message.trim()) {
    errors.message = "Message is required";
  } else if (data.message.length < 10) {
    errors.message = "Message must be at least 10 characters";
  }

  return errors;
};

/**
 * ContactForm - A fully accessible contact form with validation
 */
export const ContactForm = forwardRef<HTMLFormElement, ContactFormProps>(function ContactForm(
  { onSubmit, defaultValues = {}, loading = false, serverError, className, ...props },
  ref
) {
  const formId = useId();
  const [values, setValues] = useState<ContactFormData>({
    name: defaultValues.name ?? "",
    email: defaultValues.email ?? "",
    message: defaultValues.message ?? "",
  });
  const [errors, setErrors] = useState<ContactFormErrors>({});
  const [touched, setTouched] = useState<Record<string, boolean>>({});

  const handleChange =
    (field: keyof ContactFormData) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      const newValues = { ...values, [field]: e.target.value };
      setValues(newValues);

      // Clear error when user starts typing
      if (errors[field]) {
        const newErrors = validate(newValues);
        setErrors((prev) => ({ ...prev, [field]: newErrors[field] }));
      }
    };

  const handleBlur = (field: keyof ContactFormData) => () => {
    setTouched((prev) => ({ ...prev, [field]: true }));
    const newErrors = validate(values);
    setErrors((prev) => ({ ...prev, [field]: newErrors[field] }));
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    const newErrors = validate(values);
    setErrors(newErrors);
    setTouched({ name: true, email: true, message: true });

    if (Object.keys(newErrors).length === 0) {
      await onSubmit(values);
    }
  };

  const getFieldError = (field: keyof ContactFormData) =>
    touched[field] ? errors[field] : undefined;

  return (
    <form
      ref={ref}
      onSubmit={handleSubmit}
      className={cn("space-y-4", className)}
      aria-busy={loading}
      noValidate
      {...props}
    >
      {serverError && (
        <div
          role="alert"
          className="rounded-md border border-destructive bg-destructive/10 p-3 text-sm text-destructive"
        >
          {serverError}
        </div>
      )}

      {/* Name Field */}
      <div className="space-y-1">
        <label htmlFor={`${formId}-name`} className="text-sm font-medium">
          Name
        </label>
        <input
          id={`${formId}-name`}
          type="text"
          value={values.name}
          onChange={handleChange("name")}
          onBlur={handleBlur("name")}
          disabled={loading}
          aria-invalid={!!getFieldError("name")}
          aria-describedby={getFieldError("name") ? `${formId}-name-error` : undefined}
          className={cn(
            "w-full rounded-md border px-3 py-2",
            "focus:outline-none focus:ring-2 focus:ring-primary",
            getFieldError("name") && "border-destructive"
          )}
          autoComplete="name"
        />
        {getFieldError("name") && (
          <p id={`${formId}-name-error`} className="text-sm text-destructive" role="alert">
            {getFieldError("name")}
          </p>
        )}
      </div>

      {/* Email Field */}
      <div className="space-y-1">
        <label htmlFor={`${formId}-email`} className="text-sm font-medium">
          Email
        </label>
        <input
          id={`${formId}-email`}
          type="email"
          value={values.email}
          onChange={handleChange("email")}
          onBlur={handleBlur("email")}
          disabled={loading}
          aria-invalid={!!getFieldError("email")}
          aria-describedby={getFieldError("email") ? `${formId}-email-error` : undefined}
          className={cn(
            "w-full rounded-md border px-3 py-2",
            "focus:outline-none focus:ring-2 focus:ring-primary",
            getFieldError("email") && "border-destructive"
          )}
          autoComplete="email"
        />
        {getFieldError("email") && (
          <p id={`${formId}-email-error`} className="text-sm text-destructive" role="alert">
            {getFieldError("email")}
          </p>
        )}
      </div>

      {/* Message Field */}
      <div className="space-y-1">
        <label htmlFor={`${formId}-message`} className="text-sm font-medium">
          Message
        </label>
        <textarea
          id={`${formId}-message`}
          value={values.message}
          onChange={handleChange("message")}
          onBlur={handleBlur("message")}
          disabled={loading}
          rows={4}
          aria-invalid={!!getFieldError("message")}
          aria-describedby={getFieldError("message") ? `${formId}-message-error` : undefined}
          className={cn(
            "w-full resize-none rounded-md border px-3 py-2",
            "focus:outline-none focus:ring-2 focus:ring-primary",
            getFieldError("message") && "border-destructive"
          )}
        />
        {getFieldError("message") && (
          <p id={`${formId}-message-error`} className="text-sm text-destructive" role="alert">
            {getFieldError("message")}
          </p>
        )}
      </div>

      {/* Submit Button */}
      <button
        type="submit"
        disabled={loading}
        className={cn(
          "w-full rounded-md bg-primary px-4 py-2 text-primary-foreground",
          "font-medium transition-colors",
          "hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary",
          "disabled:cursor-not-allowed disabled:opacity-50"
        )}
      >
        {loading ? "Sending..." : "Send Message"}
      </button>
    </form>
  );
});

ContactForm.displayName = "ContactForm";
```

---

## Step 3: Generate Tests

```tsx
// src/components/ContactForm/ContactForm.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { ContactForm } from "./ContactForm";

describe("ContactForm", () => {
  const mockSubmit = vi.fn();

  beforeEach(() => {
    mockSubmit.mockClear();
  });

  describe("rendering", () => {
    it("renders all form fields", () => {
      render(<ContactForm onSubmit={mockSubmit} />);

      expect(screen.getByLabelText("Name")).toBeInTheDocument();
      expect(screen.getByLabelText("Email")).toBeInTheDocument();
      expect(screen.getByLabelText("Message")).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /send message/i })).toBeInTheDocument();
    });

    it("renders with default values", () => {
      render(
        <ContactForm
          onSubmit={mockSubmit}
          defaultValues={{ name: "John", email: "john@example.com" }}
        />
      );

      expect(screen.getByLabelText("Name")).toHaveValue("John");
      expect(screen.getByLabelText("Email")).toHaveValue("john@example.com");
    });

    it("shows server error when provided", () => {
      render(<ContactForm onSubmit={mockSubmit} serverError="Failed to send message" />);

      expect(screen.getByRole("alert")).toHaveTextContent("Failed to send message");
    });
  });

  describe("validation", () => {
    it("shows error for empty name on blur", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      const nameInput = screen.getByLabelText("Name");
      await user.click(nameInput);
      await user.tab();

      expect(await screen.findByText("Name is required")).toBeInTheDocument();
    });

    it("shows error for invalid email", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      const emailInput = screen.getByLabelText("Email");
      await user.type(emailInput, "invalid-email");
      await user.tab();

      expect(await screen.findByText("Please enter a valid email address")).toBeInTheDocument();
    });

    it("shows error for short message", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      const messageInput = screen.getByLabelText("Message");
      await user.type(messageInput, "Hi");
      await user.tab();

      expect(await screen.findByText("Message must be at least 10 characters")).toBeInTheDocument();
    });

    it("clears error when user corrects input", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      const nameInput = screen.getByLabelText("Name");
      await user.click(nameInput);
      await user.tab();

      expect(await screen.findByText("Name is required")).toBeInTheDocument();

      await user.type(nameInput, "John Doe");

      await waitFor(() => {
        expect(screen.queryByText("Name is required")).not.toBeInTheDocument();
      });
    });
  });

  describe("submission", () => {
    it("calls onSubmit with form data when valid", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      await user.type(screen.getByLabelText("Name"), "John Doe");
      await user.type(screen.getByLabelText("Email"), "john@example.com");
      await user.type(screen.getByLabelText("Message"), "Hello, this is a test message.");
      await user.click(screen.getByRole("button", { name: /send message/i }));

      expect(mockSubmit).toHaveBeenCalledWith({
        name: "John Doe",
        email: "john@example.com",
        message: "Hello, this is a test message.",
      });
    });

    it("does not call onSubmit when form is invalid", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      await user.click(screen.getByRole("button", { name: /send message/i }));

      expect(mockSubmit).not.toHaveBeenCalled();
    });

    it("shows all errors on submit attempt", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      await user.click(screen.getByRole("button", { name: /send message/i }));

      expect(await screen.findByText("Name is required")).toBeInTheDocument();
      expect(screen.getByText("Email is required")).toBeInTheDocument();
      expect(screen.getByText("Message is required")).toBeInTheDocument();
    });
  });

  describe("loading state", () => {
    it("disables inputs when loading", () => {
      render(<ContactForm onSubmit={mockSubmit} loading />);

      expect(screen.getByLabelText("Name")).toBeDisabled();
      expect(screen.getByLabelText("Email")).toBeDisabled();
      expect(screen.getByLabelText("Message")).toBeDisabled();
      expect(screen.getByRole("button")).toBeDisabled();
    });

    it("shows loading text on button", () => {
      render(<ContactForm onSubmit={mockSubmit} loading />);

      expect(screen.getByRole("button")).toHaveTextContent("Sending...");
    });
  });

  describe("accessibility", () => {
    it("has proper aria-invalid on error fields", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      await user.click(screen.getByRole("button", { name: /send message/i }));

      expect(screen.getByLabelText("Name")).toHaveAttribute("aria-invalid", "true");
    });

    it("links error messages with aria-describedby", async () => {
      const user = userEvent.setup();
      render(<ContactForm onSubmit={mockSubmit} />);

      const nameInput = screen.getByLabelText("Name");
      await user.click(nameInput);
      await user.tab();

      const errorId = nameInput.getAttribute("aria-describedby");
      expect(errorId).toBeTruthy();
      expect(document.getElementById(errorId!)).toHaveTextContent("Name is required");
    });

    it("sets aria-busy on form when loading", () => {
      const { container } = render(<ContactForm onSubmit={mockSubmit} loading />);
      expect(container.querySelector("form")).toHaveAttribute("aria-busy", "true");
    });
  });
});
```

---

## Step 4: Create Index File

```typescript
// src/components/ContactForm/index.ts
export { ContactForm } from "./ContactForm";
export type { ContactFormProps, ContactFormData, ContactFormErrors } from "./types";
```

---

## Results

Final structure:

```
src/components/ContactForm/
├── ContactForm.tsx         # 150 lines
├── ContactForm.test.tsx    # 140 lines
├── index.ts                # 2 lines
└── types.ts                # 35 lines
```

**Key features implemented**:

- Real-time validation with blur triggers
- Clear error messages linked via aria-describedby
- Loading state that disables all interactions
- Server error display
- Full keyboard navigation
- 100% test coverage of critical paths
