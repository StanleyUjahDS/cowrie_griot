import {
    getCurrentUser,
} from "../../users/user.service.js";

import {
    getWalletSupportedNetworks,
    getWalletNativeBalance,
    getWalletNativeBalances,
    getWalletTokenBalances,
    getWalletAssets,
    getWalletAssetsByNetwork,
    getWalletCustomToken,
} from "./wallet.service.js";

import {
    getOfficialMarketData,
} from "../market/market.service.js";


async function getAuthenticatedWalletAddress(req) {
    const userId = req.user?.id;

    if (!userId) {
        const error = new Error(
            "Authenticated user is required"
        );
        error.statusCode = 401;
        throw error;
    }

    const user =
        await getCurrentUser(userId);

    if (!user.wallet_address) {
        const error = new Error(
            "No wallet address is associated with this user"
        );
        error.statusCode = 400;
        throw error;
    }

    return user.wallet_address;
}


function toNumber(value) {
    const number = Number(value);

    return Number.isFinite(number)
        ? number
        : null;
}


async function enrichAssetsWithMarketData(assets) {
    const marketData =
        await getOfficialMarketData();

    const marketById =
        new Map(
            marketData.map((item) => [
                item.id,
                item.market,
            ])
        );

    return assets.map((asset) => {
        const market =
            marketById.get(asset.id) || null;

        const price =
            toNumber(market?.price);

        const balance =
            toNumber(asset.balance);

        const valueUsd =
            price !== null &&
            balance !== null
                ? price * balance
                : null;

        return {
            ...asset,

            price,

            valueUsd,

            change24h:
                toNumber(market?.change24h),

            marketCap:
                toNumber(market?.marketCap),

            logo:
                asset.logo ||
                market?.logo ||
                null,
        };
    });
}


export async function getSupportedNetworks(req, res) {
    try {
        return res.status(200).json({
            success: true,
            data: getWalletSupportedNetworks(),
        });
    } catch (error) {
        console.error("Get supported networks error:", error);
        return res.status(500).json({
            success: false,
            message: "Failed to get supported networks",
        });
    }
}


export async function getNativeBalance(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const balance =
            await getWalletNativeBalance({
                address,
                network: req.params.network,
            });

        return res.status(200).json({
            success: true,
            data: balance,
        });
    } catch (error) {
        console.error("Get native balance error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get wallet balance",
        });
    }
}


export async function getNativeBalances(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const balances =
            await getWalletNativeBalances(address);

        return res.status(200).json({
            success: true,
            data: balances,
        });
    } catch (error) {
        console.error("Get native balances error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get wallet balances",
        });
    }
}


export async function getTokens(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const requestedNetworks =
            req.query.networks
                ? req.query.networks
                    .split(",")
                    .map((network) => network.trim())
                    .filter(Boolean)
                : getWalletSupportedNetworks().map(
                    (network) => network.network
                );

        const tokens =
            await getWalletTokenBalances({
                address,
                networks: requestedNetworks,
            });

        return res.status(200).json({
            success: true,
            data: tokens,
        });
    } catch (error) {
        console.error("Get wallet tokens error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get wallet tokens",
        });
    }
}


export async function getAssets(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const networks =
            req.query.networks
                ? req.query.networks
                    .split(",")
                    .map((network) => network.trim())
                    .filter(Boolean)
                : undefined;

        const result =
            await getWalletAssets({
                address,
                networks,
            });

        const assets =
            await enrichAssetsWithMarketData(
                result.assets
            );

        const totalBalanceUsd =
            assets.reduce(
                (total, asset) =>
                    total +
                    (asset.valueUsd || 0),
                0
            );

        return res.status(200).json({
            success: true,
            data: {
                ...result,
                assets,
                totalBalanceUsd,
            },
        });
    } catch (error) {
        console.error("Get wallet assets error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get wallet assets",
        });
    }
}


export async function getAssetsByNetwork(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const result =
            await getWalletAssetsByNetwork({
                address,
                network: req.params.network,
            });

        const assets =
            await enrichAssetsWithMarketData(
                result.assets
            );

        const totalBalanceUsd =
            assets.reduce(
                (total, asset) =>
                    total +
                    (asset.valueUsd || 0),
                0
            );

        return res.status(200).json({
            success: true,
            data: {
                ...result,
                assets,
                totalBalanceUsd,
            },
        });
    } catch (error) {
        console.error("Get wallet assets by network error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get wallet assets",
        });
    }
}


export async function getCustomToken(req, res) {
    try {
        const address =
            await getAuthenticatedWalletAddress(req);

        const token =
            await getWalletCustomToken({
                address,
                network: req.params.network,
                tokenAddress: req.params.tokenAddress,
            });

        return res.status(200).json({
            success: true,
            data: token,
        });
    } catch (error) {
        console.error("Get custom token error:", error);
        return res.status(error.statusCode || 400).json({
            success: false,
            message: error.message || "Failed to get custom token",
        });
    }
}
