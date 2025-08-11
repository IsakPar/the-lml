import { diag, DiagConsoleLogger, DiagLogLevel } from '@opentelemetry/api';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import * as otelResources from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

let initialized = false;

export function initTracing(): void {
  if (initialized) return;
  const enabled = process.env.ENABLE_OTEL === '1' || process.env.OTEL_EXPORTER_OTLP_ENDPOINT || process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT;
  if (!enabled) return;
  try {
    diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.ERROR);
    const serviceName = process.env.OTEL_SERVICE_NAME || 'thankful-api';
    const resource = new (otelResources as any).Resource({ [SemanticResourceAttributes.SERVICE_NAME]: serviceName });
    const provider = new NodeTracerProvider({ resource });
    const url = String(process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || (process.env.OTEL_EXPORTER_OTLP_ENDPOINT ? `${process.env.OTEL_EXPORTER_OTLP_ENDPOINT.replace(/\/$/, '')}/v1/traces` : 'http://localhost:4318/v1/traces'));
    const exporter = new OTLPTraceExporter({ url });
    (provider as any).addSpanProcessor(new BatchSpanProcessor(exporter));
    provider.register();
    initialized = true;
    // eslint-disable-next-line no-console
    console.log(`[otel] tracing initialized -> ${url}`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[otel] init failed', err);
  }
}


