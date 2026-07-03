import { Injectable } from '@nestjs/common';
import { InitiateResult, PaymentProvider } from './payment-provider';

// Fournisseur simulé pour le développement et les démos :
// pas d'appel réseau, l'URL de checkout est fictive et la confirmation
// est déclenchée automatiquement par PaymentsService après 2 s.
@Injectable()
export class MockPaymentProvider implements PaymentProvider {
  readonly name = 'mock';

  async initiate(params: {
    reference: string;
    amountFcfa: number;
    method: string;
  }): Promise<InitiateResult> {
    return {
      aggregatorRef: params.reference,
      paymentUrl: `https://pay.mock.gologui.sn/checkout/${params.reference}`,
    };
  }

  verifyWebhook(): boolean {
    return true; // aucun contrôle en dev
  }
}
