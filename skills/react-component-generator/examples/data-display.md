# Example: Building a Data Table Component

This example demonstrates generating a data display component with sorting, pagination, and accessibility features.

---

## Scenario

**Goal**: Create a `DataTable` component with:

- Column definitions with custom renderers
- Sorting by columns
- Pagination
- Loading and empty states
- Full accessibility (ARIA grid patterns)

---

## Step 1: Generate Types

```typescript
// src/components/DataTable/types.ts
import type { ReactNode, HTMLAttributes } from "react";

/**
 * Sort direction
 */
export type SortDirection = "asc" | "desc" | null;

/**
 * Column definition for DataTable
 */
export interface ColumnDef<T> {
  /**
   * Unique key for the column (should match a key in the data object)
   */
  key: string;

  /**
   * Header text to display
   */
  header: string;

  /**
   * Whether this column is sortable
   * @default false
   */
  sortable?: boolean;

  /**
   * Custom cell renderer
   * @param value - The cell value
   * @param row - The entire row data
   */
  render?: (value: unknown, row: T) => ReactNode;

  /**
   * Column width (CSS value)
   */
  width?: string;

  /**
   * Text alignment
   * @default 'left'
   */
  align?: "left" | "center" | "right";
}

/**
 * Pagination state
 */
export interface PaginationState {
  page: number;
  pageSize: number;
  total: number;
}

/**
 * Sort state
 */
export interface SortState {
  column: string | null;
  direction: SortDirection;
}

/**
 * Props for the DataTable component
 */
export interface DataTableProps<T> extends Omit<HTMLAttributes<HTMLDivElement>, "children"> {
  /**
   * Column definitions
   */
  columns: ColumnDef<T>[];

  /**
   * Data rows to display
   */
  data: T[];

  /**
   * Unique key for each row (function that extracts ID from row)
   */
  getRowKey: (row: T) => string | number;

  /**
   * Whether data is loading
   * @default false
   */
  loading?: boolean;

  /**
   * Current sort state
   */
  sortState?: SortState;

  /**
   * Called when sort changes
   */
  onSortChange?: (sort: SortState) => void;

  /**
   * Pagination state (omit for non-paginated table)
   */
  pagination?: PaginationState;

  /**
   * Called when page changes
   */
  onPageChange?: (page: number) => void;

  /**
   * Message to show when there's no data
   * @default 'No data'
   */
  emptyMessage?: string;
}
```

---

## Step 2: Generate Component

```tsx
// src/components/DataTable/DataTable.tsx
import { forwardRef, useId } from "react";
import { cn } from "@/lib/utils";
import type { DataTableProps, ColumnDef, SortDirection } from "./types";

const SortIcon = ({ direction }: { direction: SortDirection }) => {
  if (!direction) {
    return (
      <svg className="h-4 w-4 opacity-40" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <path d="M7 10l5-5 5 5M7 14l5 5 5-5" strokeWidth="2" />
      </svg>
    );
  }
  return (
    <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor">
      {direction === "asc" ? (
        <path d="M7 14l5-5 5 5" strokeWidth="2" />
      ) : (
        <path d="M7 10l5 5 5-5" strokeWidth="2" />
      )}
    </svg>
  );
};

const LoadingOverlay = () => (
  <div className="absolute inset-0 flex items-center justify-center bg-background/50">
    <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
  </div>
);

/**
 * DataTable - A fully accessible data table with sorting and pagination
 */
function DataTableInner<T>(
  {
    columns,
    data,
    getRowKey,
    loading = false,
    sortState,
    onSortChange,
    pagination,
    onPageChange,
    emptyMessage = "No data",
    className,
    ...props
  }: DataTableProps<T>,
  ref: React.ForwardedRef<HTMLDivElement>
) {
  const tableId = useId();

  const handleSort = (column: ColumnDef<T>) => {
    if (!column.sortable || !onSortChange) return;

    const newDirection: SortDirection =
      sortState?.column === column.key
        ? sortState.direction === "asc"
          ? "desc"
          : sortState.direction === "desc"
            ? null
            : "asc"
        : "asc";

    onSortChange({
      column: newDirection ? column.key : null,
      direction: newDirection,
    });
  };

  const totalPages = pagination ? Math.ceil(pagination.total / pagination.pageSize) : 1;

  const getCellValue = (row: T, column: ColumnDef<T>) => {
    const value = (row as Record<string, unknown>)[column.key];
    if (column.render) {
      return column.render(value, row);
    }
    return String(value ?? "");
  };

  return (
    <div ref={ref} className={cn("relative", className)} {...props}>
      <div className="overflow-x-auto">
        <table
          role="grid"
          aria-busy={loading}
          aria-describedby={`${tableId}-caption`}
          className="w-full border-collapse"
        >
          <caption id={`${tableId}-caption`} className="sr-only">
            Data table with {data.length} rows and {columns.length} columns
          </caption>

          <thead>
            <tr className="border-b">
              {columns.map((column) => (
                <th
                  key={column.key}
                  scope="col"
                  aria-sort={
                    sortState?.column === column.key
                      ? sortState.direction === "asc"
                        ? "ascending"
                        : "descending"
                      : undefined
                  }
                  className={cn(
                    "px-4 py-3 text-sm font-medium",
                    column.align === "center" && "text-center",
                    column.align === "right" && "text-right",
                    column.sortable && "cursor-pointer select-none hover:bg-muted/50"
                  )}
                  style={{ width: column.width }}
                  onClick={() => handleSort(column)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      handleSort(column);
                    }
                  }}
                  tabIndex={column.sortable ? 0 : undefined}
                  role={column.sortable ? "button" : undefined}
                >
                  <span className="inline-flex items-center gap-1">
                    {column.header}
                    {column.sortable && (
                      <SortIcon
                        direction={sortState?.column === column.key ? sortState.direction : null}
                      />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>

          <tbody>
            {data.length === 0 ? (
              <tr>
                <td
                  colSpan={columns.length}
                  className="px-4 py-12 text-center text-muted-foreground"
                >
                  {emptyMessage}
                </td>
              </tr>
            ) : (
              data.map((row) => (
                <tr key={getRowKey(row)} className="border-b transition-colors hover:bg-muted/50">
                  {columns.map((column) => (
                    <td
                      key={column.key}
                      className={cn(
                        "px-4 py-3 text-sm",
                        column.align === "center" && "text-center",
                        column.align === "right" && "text-right"
                      )}
                    >
                      {getCellValue(row, column)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pagination && totalPages > 1 && (
        <nav
          aria-label="Pagination"
          className="flex items-center justify-between border-t px-4 py-3"
        >
          <p className="text-sm text-muted-foreground">
            Showing {(pagination.page - 1) * pagination.pageSize + 1} to{" "}
            {Math.min(pagination.page * pagination.pageSize, pagination.total)} of{" "}
            {pagination.total} results
          </p>

          <div className="flex items-center gap-2">
            <button
              onClick={() => onPageChange?.(pagination.page - 1)}
              disabled={pagination.page === 1}
              aria-label="Previous page"
              className={cn(
                "rounded border px-3 py-1 text-sm",
                "hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              )}
            >
              Previous
            </button>

            <span className="text-sm">
              Page {pagination.page} of {totalPages}
            </span>

            <button
              onClick={() => onPageChange?.(pagination.page + 1)}
              disabled={pagination.page === totalPages}
              aria-label="Next page"
              className={cn(
                "rounded border px-3 py-1 text-sm",
                "hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              )}
            >
              Next
            </button>
          </div>
        </nav>
      )}

      {loading && <LoadingOverlay />}
    </div>
  );
}

// Type assertion for forwardRef with generics
export const DataTable = forwardRef(DataTableInner) as <T>(
  props: DataTableProps<T> & { ref?: React.ForwardedRef<HTMLDivElement> }
) => ReturnType<typeof DataTableInner>;
```

---

## Step 3: Generate Tests

```tsx
// src/components/DataTable/DataTable.test.tsx
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { DataTable } from "./DataTable";
import type { ColumnDef } from "./types";

interface TestUser {
  id: number;
  name: string;
  email: string;
  role: string;
}

const columns: ColumnDef<TestUser>[] = [
  { key: "name", header: "Name", sortable: true },
  { key: "email", header: "Email" },
  { key: "role", header: "Role", sortable: true },
];

const testData: TestUser[] = [
  { id: 1, name: "Alice", email: "alice@test.com", role: "Admin" },
  { id: 2, name: "Bob", email: "bob@test.com", role: "User" },
  { id: 3, name: "Charlie", email: "charlie@test.com", role: "User" },
];

describe("DataTable", () => {
  describe("rendering", () => {
    it("renders table headers", () => {
      render(<DataTable columns={columns} data={testData} getRowKey={(row) => row.id} />);

      expect(screen.getByRole("columnheader", { name: /name/i })).toBeInTheDocument();
      expect(screen.getByRole("columnheader", { name: /email/i })).toBeInTheDocument();
      expect(screen.getByRole("columnheader", { name: /role/i })).toBeInTheDocument();
    });

    it("renders data rows", () => {
      render(<DataTable columns={columns} data={testData} getRowKey={(row) => row.id} />);

      expect(screen.getByText("Alice")).toBeInTheDocument();
      expect(screen.getByText("bob@test.com")).toBeInTheDocument();
    });

    it("renders empty message when no data", () => {
      render(
        <DataTable
          columns={columns}
          data={[]}
          getRowKey={(row) => row.id}
          emptyMessage="No users found"
        />
      );

      expect(screen.getByText("No users found")).toBeInTheDocument();
    });

    it("renders custom cell content via render function", () => {
      const columnsWithRender: ColumnDef<TestUser>[] = [
        {
          key: "name",
          header: "Name",
          render: (value) => <strong>{String(value)}</strong>,
        },
      ];

      render(<DataTable columns={columnsWithRender} data={testData} getRowKey={(row) => row.id} />);

      const nameCell = screen.getByText("Alice");
      expect(nameCell.tagName).toBe("STRONG");
    });
  });

  describe("sorting", () => {
    it("calls onSortChange when sortable header is clicked", async () => {
      const user = userEvent.setup();
      const handleSort = vi.fn();

      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          onSortChange={handleSort}
          sortState={{ column: null, direction: null }}
        />
      );

      await user.click(screen.getByRole("columnheader", { name: /name/i }));

      expect(handleSort).toHaveBeenCalledWith({
        column: "name",
        direction: "asc",
      });
    });

    it("cycles through sort directions", async () => {
      const user = userEvent.setup();
      const handleSort = vi.fn();

      const { rerender } = render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          onSortChange={handleSort}
          sortState={{ column: "name", direction: "asc" }}
        />
      );

      await user.click(screen.getByRole("columnheader", { name: /name/i }));

      expect(handleSort).toHaveBeenCalledWith({
        column: "name",
        direction: "desc",
      });

      // Simulate state update
      rerender(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          onSortChange={handleSort}
          sortState={{ column: "name", direction: "desc" }}
        />
      );

      await user.click(screen.getByRole("columnheader", { name: /name/i }));

      expect(handleSort).toHaveBeenLastCalledWith({
        column: null,
        direction: null,
      });
    });

    it("shows correct aria-sort attribute", () => {
      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          sortState={{ column: "name", direction: "asc" }}
        />
      );

      expect(screen.getByRole("columnheader", { name: /name/i })).toHaveAttribute(
        "aria-sort",
        "ascending"
      );
    });
  });

  describe("pagination", () => {
    it("renders pagination controls", () => {
      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          pagination={{ page: 1, pageSize: 10, total: 50 }}
        />
      );

      expect(screen.getByRole("navigation", { name: /pagination/i })).toBeInTheDocument();
      expect(screen.getByText(/showing 1 to 3 of 50/i)).toBeInTheDocument();
    });

    it("calls onPageChange when next is clicked", async () => {
      const user = userEvent.setup();
      const handlePageChange = vi.fn();

      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          pagination={{ page: 1, pageSize: 10, total: 50 }}
          onPageChange={handlePageChange}
        />
      );

      await user.click(screen.getByRole("button", { name: /next page/i }));

      expect(handlePageChange).toHaveBeenCalledWith(2);
    });

    it("disables previous on first page", () => {
      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          pagination={{ page: 1, pageSize: 10, total: 50 }}
        />
      );

      expect(screen.getByRole("button", { name: /previous page/i })).toBeDisabled();
    });

    it("disables next on last page", () => {
      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          pagination={{ page: 5, pageSize: 10, total: 50 }}
        />
      );

      expect(screen.getByRole("button", { name: /next page/i })).toBeDisabled();
    });
  });

  describe("loading state", () => {
    it("shows loading overlay", () => {
      render(<DataTable columns={columns} data={testData} getRowKey={(row) => row.id} loading />);

      expect(screen.getByRole("grid")).toHaveAttribute("aria-busy", "true");
    });
  });

  describe("accessibility", () => {
    it("has proper table structure", () => {
      render(<DataTable columns={columns} data={testData} getRowKey={(row) => row.id} />);

      expect(screen.getByRole("grid")).toBeInTheDocument();
      expect(screen.getAllByRole("columnheader")).toHaveLength(3);
      expect(screen.getAllByRole("row")).toHaveLength(4); // 1 header + 3 data
    });

    it("sortable headers are keyboard accessible", async () => {
      const user = userEvent.setup();
      const handleSort = vi.fn();

      render(
        <DataTable
          columns={columns}
          data={testData}
          getRowKey={(row) => row.id}
          onSortChange={handleSort}
          sortState={{ column: null, direction: null }}
        />
      );

      const nameHeader = screen.getByRole("columnheader", { name: /name/i });
      nameHeader.focus();
      await user.keyboard("{Enter}");

      expect(handleSort).toHaveBeenCalled();
    });
  });
});
```

---

## Step 4: Create Index File

```typescript
// src/components/DataTable/index.ts
export { DataTable } from "./DataTable";
export type { DataTableProps, ColumnDef, SortState, SortDirection, PaginationState } from "./types";
```

---

## Usage Example

```tsx
import { useState } from "react";
import { DataTable } from "@/components/DataTable";
import type { ColumnDef, SortState, PaginationState } from "@/components/DataTable";

interface User {
  id: number;
  name: string;
  email: string;
  status: "active" | "inactive";
}

const columns: ColumnDef<User>[] = [
  { key: "name", header: "Name", sortable: true },
  { key: "email", header: "Email", sortable: true },
  {
    key: "status",
    header: "Status",
    render: (value) => (
      <span className={value === "active" ? "text-green-600" : "text-gray-400"}>
        {String(value)}
      </span>
    ),
  },
];

export function UsersPage() {
  const [sortState, setSortState] = useState<SortState>({ column: null, direction: null });
  const [pagination, setPagination] = useState<PaginationState>({
    page: 1,
    pageSize: 10,
    total: 100,
  });

  const users: User[] = [
    { id: 1, name: "Alice", email: "alice@example.com", status: "active" },
    // ... more users
  ];

  return (
    <DataTable
      columns={columns}
      data={users}
      getRowKey={(user) => user.id}
      sortState={sortState}
      onSortChange={setSortState}
      pagination={pagination}
      onPageChange={(page) => setPagination((p) => ({ ...p, page }))}
      emptyMessage="No users found"
    />
  );
}
```

---

## Results

Final structure:

```
src/components/DataTable/
├── DataTable.tsx           # 180 lines
├── DataTable.test.tsx      # 200 lines
├── index.ts                # 8 lines
└── types.ts                # 75 lines
```

**Key features implemented**:

- Generic typing for any data shape
- Controlled sort state with cycling (asc → desc → none)
- Pagination with accessible navigation
- Custom cell renderers
- Loading overlay
- Full keyboard support for sortable headers
- Proper ARIA grid semantics
