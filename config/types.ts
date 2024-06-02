import { type GetContractReturnType } from '@nomicfoundation/hardhat-viem/types';
import { type Abi } from 'viem';
import { z } from 'zod';

const networks = [
  'main',
  'sepolia',
  'hardhat',
  'localhost',
  'polygon',
] as const;
export const networksEnum = z.enum(networks);

export type Network = z.infer<typeof networksEnum>;
export type RpcUrl = string;
export type NetworkConfigParam<T> = Record<Network, T>;

export type Contract<
  T extends { abi: Abi | readonly unknown[] } = { abi: [] },
> = GetContractReturnType<T['abi']>;
