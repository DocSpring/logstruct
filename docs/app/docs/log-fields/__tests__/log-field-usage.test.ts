import { LogField } from '@/generated/logstruct/enums';
import exampleLines from '../example-lines.json';
import {
  builtInLogTypes,
  logFieldRows,
  propertiesWithoutLogField,
  propertyName,
  typeCategory,
} from '../log-field-usage';

describe('log field usage', () => {
  test('every property of the built-in log types is a LogField, except additional_data', () => {
    expect(propertiesWithoutLogField()).toEqual(['additional_data']);
  });

  test('has a row for every LogField, with its JSON key', () => {
    const rows = logFieldRows();
    expect(rows).toHaveLength(Object.keys(LogField).length);
    expect(rows.find((row) => row.name === 'MailerClass')?.key).toBe('mailer');
    expect(rows.find((row) => row.name === 'Database')?.key).toBe('db');
  });

  test('lists the log types that write each field', () => {
    const usedBy = (name: string) => logFieldRows().find((row) => row.name === name)?.usedBy;
    expect(usedBy('Timestamp')).toEqual(['Every log type']);
    expect(usedBy('Database')).toEqual(['Log::Request']);
    expect(usedBy('JobId')).toEqual(['Log::ActiveJob::*', 'Log::GoodJob::*']);
    expect(usedBy('ErrorContext')).toEqual(['Log::Puma::Error', 'Log::Sidekiq::Error']);
    expect(usedBy('RequestId')).toEqual([]);
  });

  test('maps LogField names to the log types’ property names', () => {
    expect(propertyName('MailerClass')).toBe('mailer_class');
    expect(propertyName('SourceIp')).toBe('source_ip');
    expect(propertyName('CSRFViolation')).toBe('csrf_violation');
  });

  test('groups log types by source', () => {
    expect(typeCategory('LogStruct::Log::ActiveJob::Enqueue')).toBe('Log::ActiveJob');
    expect(typeCategory('LogStruct::Log::Request')).toBe('Log::Request');
  });

  test('the example lines cover every built-in log type', () => {
    expect(Object.keys(exampleLines.lines).sort()).toEqual(builtInLogTypes());
  });

  test('every example line has the common keys and only short names', () => {
    const keys = new Set<string>(Object.values(LogField));
    const metadata = ['prog', 'tags', 'req_id', 'ctx'];
    // Keys that the examples' additional_data adds
    const additional = ['account_id', 'user_id'];
    for (const line of Object.values(exampleLines.lines) as Array<Record<string, unknown>>) {
      for (const key of ['src', 'evt', 'lvl', 'ts']) expect(line).toHaveProperty(key);
      for (const key of Object.keys(line)) {
        expect(keys.has(key) || metadata.includes(key) || additional.includes(key)).toBe(true);
      }
    }
  });
});
