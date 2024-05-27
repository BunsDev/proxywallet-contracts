import 'dotenv/config';

import { z } from 'zod';

import { createEnv } from '@/config/create-env';
import { networksEnum } from '@/config/types';

export const env = createEnv({
  server: {
    INFURA_KEY: z.string().optional(),
    MNEMONIC_DEV: z.string().optional(),
    MNEMONIC_PROD: z.string().optional(),
    FORKING_NETWORK: networksEnum.optional(),
    ETHERSCAN_API_KEY: z.string().optional(),
    SOLIDITY_COVERAGE: z
      .string()
      .optional()
      .transform((value) => value === 'true'),
  },
  runtimeEnv: process.env,
  emptyStringAsUndefined: true,
});
