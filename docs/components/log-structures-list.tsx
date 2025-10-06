import { cache } from 'react';
import { getLogStructureDescription } from '@/lib/log-structure-descriptions';

// Interface for the structure in the log structs JSON file
interface StructField {
  type: string;
  optional?: boolean;
  [key: string]: unknown;
}

interface StructEntry {
  name: string;
  simple_name: string;
  fields: Record<string, StructField>;
}

type LogStructsData = Record<string, StructEntry>;

// Function to get log structs data from JSON file with caching
const getLogStructsData = cache(async (): Promise<LogStructsData> => {
  try {
    // Use dynamic import to load the JSON file
    const data = await import('@/generated/logstruct/sorbet-log-structs.json');
    return data.default as LogStructsData;
  } catch (error) {
    console.error('Error loading log structures data:', error);
    return {};
  }
});

/**
 * Component that displays a bullet point list of LogStruct log structures
 * with their descriptions
 */
export async function LogStructuresList() {
  // Get the log structs data
  const structsData = await getLogStructsData();

  const categoryMap = new Map<
    string,
    Array<{
      label: string | null;
      description: string;
    }>
  >();

  Object.entries(structsData).forEach(([fullName, entry]) => {
    if (entry.simple_name === 'BaseFields') {
      return;
    }

    const trimmed = fullName.replace(/^LogStruct::/, '');
    const parts = trimmed.split('::');
    if (parts[0] !== 'Log') {
      return;
    }

    const category = parts.length > 1 ? `Log::${parts[1]}` : 'Log';
    const variantLabel = parts.length > 2 ? parts[parts.length - 1] : null;

    const description = getLogStructureDescription(entry.simple_name);

    const list = categoryMap.get(category) ?? [];
    list.push({ label: variantLabel, description });
    categoryMap.set(category, list);
  });

  const categories = Array.from(categoryMap.entries()).sort(([a], [b]) => a.localeCompare(b));

  return (
    <div className="space-y-6">
      {categories.map(([category, variants]) => (
        <section key={category} className="space-y-3">
          <h3 className="text-xl pt-4 font-semibold text-neutral-800 dark:text-neutral-300">
            <code>{category}</code>
          </h3>
          <ul className="list-disc list-inside space-y-3 text-neutral-600 dark:text-neutral-300 ml-4">
            {variants
              .sort((a, b) => a.label?.localeCompare(b.label ?? '') ?? 0)
              .map(({ label, description }) => (
                <li key={label} className="space-y-1">
                  {label ? (
                    <>
                      <code className="py-0.5 text-neutral-800 dark:text-neutral-200 rounded">
                        {label}
                      </code>
                      {' - '}
                    </>
                  ) : null}

                  {description}
                </li>
              ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
