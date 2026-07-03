import { createHash } from 'crypto';
import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InitiateResult, PaymentProvider } from './payment-provider';

// Intégration PayDunya (https://developers.paydunya.com) — API
// checkout-invoice. Couvre Wave, Orange Money, Free Money et carte via la
// page de paiement hébergée. Activer avec PAYMENT_PROVIDER=paydunya et les
// clés PAYDUNYA_* ; PAYDUNYA_MODE=test utilise l'environnement sandbox.
@Injectable()
export class PayDunyaProvider implements PaymentProvider {
  readonly name = 'paydunya';

  private get baseUrl() {
    return process.env.PAYDUNYA_MODE === 'live'
      ? 'https://app.paydunya.com/api/v1'
      : 'https://app.paydunya.com/sandbox-api/v1';
  }

  private get headers() {
    return {
      'Content-Type': 'application/json',
      'PAYDUNYA-MASTER-KEY': process.env.PAYDUNYA_MASTER_KEY ?? '',
      'PAYDUNYA-PRIVATE-KEY': process.env.PAYDUNYA_PRIVATE_KEY ?? '',
      'PAYDUNYA-TOKEN': process.env.PAYDUNYA_TOKEN ?? '',
    };
  }

  async initiate(params: {
    reference: string;
    amountFcfa: number;
    method: string;
    description: string;
    customerPhone: string;
  }): Promise<InitiateResult> {
    const res = await fetch(`${this.baseUrl}/checkout-invoice/create`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({
        invoice: {
          total_amount: params.amountFcfa,
          description: params.description,
        },
        store: { name: 'Gologui' },
        custom_data: { reference: params.reference },
        actions: {
          callback_url: process.env.PAYMENT_CALLBACK_URL,
        },
      }),
    });
    const data = (await res.json()) as {
      response_code: string;
      response_text: string;
      token: string;
    };
    if (data.response_code !== '00') {
      throw new ServiceUnavailableException(
        `PayDunya : ${data.response_text ?? 'échec de création de la facture'}`,
      );
    }
    return {
      aggregatorRef: data.token,
      paymentUrl:
        process.env.PAYDUNYA_MODE === 'live'
          ? `https://paydunya.com/checkout/invoice/${data.token}`
          : `https://paydunya.com/sandbox-checkout/invoice/${data.token}`,
    };
  }

  // PayDunya signe ses IPN avec le hash SHA-512 de la master key.
  verifyWebhook(_headers: Record<string, string>, rawBody: string): boolean {
    try {
      const payload = JSON.parse(rawBody);
      const receivedHash = payload?.data?.hash ?? payload?.hash;
      if (!receivedHash) return false;
      const expected = createHash('sha512')
        .update(process.env.PAYDUNYA_MASTER_KEY ?? '')
        .digest('hex');
      return receivedHash === expected;
    } catch {
      return false;
    }
  }
}
